/**
 * Image Generation Relay (11 Labs - GPT Image 2.5)
 * -----------------------------------------------
 * Sits between UE5 and 11 Labs Image API. Handles asynchronous image generation
 * using polling: submit job → get ID → poll for status → fetch and base64-encode result.
 *
 * Run: node _image_generation_11lab_relay.js
 * Test: curl -X POST http://localhost:3001/generate-image -H "Content-Type: application/json" -d '{"prompt":"a cybernetic owl","model_id":"gpt-image-2.5-flare","aspect_ratio":"16:9"}'
 */

require("dotenv").config();
const express = require("express");

const app = express();
app.use(express.json());

const API_KEY = process.env.ELEVENLABS_API_KEY;
const PORT = process.env.IMAGE_PORT || 3001;
const ELEVENLABS_BASE_URL = "https://api.elevenlabs.io";

if (!API_KEY) {
  console.error("Missing ELEVENLABS_API_KEY in .env - stopping.");
  process.exit(1);
}

// In-memory job store (in production, use a database)
const jobStore = new Map();

app.get("/health", (req, res) => {
  res.json({ status: "ok", relay: "image-relay", time: new Date().toISOString() });
});

app.post("/generate-image", async (req, res) => {
  const { prompt, model_id, aspect_ratio } = req.body || {};

  if (!prompt) {
    return res.status(400).json({ error: "Missing prompt in request body." });
  }

  console.log(`[relay] Image generation request: prompt="${prompt.substring(0, 50)}..." model=${model_id || "gpt-image-2.5-flare"} aspect=${aspect_ratio || "1:1"}`);

  try {
    const elevenResponse = await fetch(`${ELEVENLABS_BASE_URL}/v1/flows/image`, {
      method: "POST",
      headers: {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_id: model_id || "gpt-image-2.5-flare",
        prompt: prompt,
        aspect_ratio: aspect_ratio || "1:1",
      }),
    });

    if (!elevenResponse.ok) {
      const errorText = await elevenResponse.text();
      console.error(`[relay] 11 Labs error ${elevenResponse.status}:`, errorText);
      return res.status(elevenResponse.status).json({ error: errorText });
    }

    const data = await elevenResponse.json();
    const imageId = data.id || data.image_id;

    if (!imageId) {
      console.error("[relay] No image ID in 11 Labs response:", data);
      return res.status(500).json({ error: "Invalid response from 11 Labs - no image ID" });
    }

    // Store job metadata
    jobStore.set(imageId, {
      prompt,
      model_id: model_id || "gpt-image-2.5-flare",
      status: "submitted",
      createdAt: Date.now(),
    });

    console.log(`[relay] Image job submitted. ID: ${imageId}`);

    res.json({ image_id: imageId, status: "submitted" });
  } catch (err) {
    console.error("[relay] Request failed:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.post("/generate-image-from-reference", async (req, res) => {
  const { prompt, model_id, aspect_ratio, image_data } = req.body || {};

  if (!prompt) {
    return res.status(400).json({ error: "Missing prompt in request body." });
  }

  if (!image_data) {
    return res.status(400).json({ error: "Missing image_data (base64 encoded image) in request body." });
  }

  console.log(`[relay] Image generation from reference: prompt="${prompt.substring(0, 50)}..." model=${model_id || "gpt-image-2.5-flare"} aspect=${aspect_ratio || "1:1"} image_size=${image_data.length} bytes`);

  try {
    const elevenResponse = await fetch(`${ELEVENLABS_BASE_URL}/v1/flows/image`, {
      method: "POST",
      headers: {
        "xi-api-key": API_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model_id: model_id || "gpt-image-2.5-flare",
        prompt: prompt,
        aspect_ratio: aspect_ratio || "1:1",
        image_data: image_data,
      }),
    });

    if (!elevenResponse.ok) {
      const errorText = await elevenResponse.text();
      console.error(`[relay] 11 Labs error ${elevenResponse.status}:`, errorText);
      return res.status(elevenResponse.status).json({ error: errorText });
    }

    const data = await elevenResponse.json();
    const imageId = data.id || data.image_id;

    if (!imageId) {
      console.error("[relay] No image ID in 11 Labs response:", data);
      return res.status(500).json({ error: "Invalid response from 11 Labs - no image ID" });
    }

    // Store job metadata
    jobStore.set(imageId, {
      prompt,
      model_id: model_id || "gpt-image-2.5-flare",
      status: "submitted",
      hasReference: true,
      createdAt: Date.now(),
    });

    console.log(`[relay] Image job from reference submitted. ID: ${imageId}`);

    res.json({ image_id: imageId, status: "submitted" });
  } catch (err) {
    console.error("[relay] Image reference request failed:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.get("/image-status", async (req, res) => {
  const { image_id } = req.query;

  if (!image_id) {
    return res.status(400).json({ error: "Missing image_id query parameter." });
  }

  console.log(`[relay] Status check for image_id: ${image_id}`);

  try {
    const elevenResponse = await fetch(`${ELEVENLABS_BASE_URL}/v1/flows/image/${image_id}`, {
      method: "GET",
      headers: {
        "xi-api-key": API_KEY,
      },
    });

    if (!elevenResponse.ok) {
      const errorText = await elevenResponse.text();
      console.error(`[relay] 11 Labs error ${elevenResponse.status}:`, errorText);
      return res.status(elevenResponse.status).json({ error: errorText });
    }

    const data = await elevenResponse.json();
    const status = data.status || "unknown";

    if (status === "success" && data.image_url) {
      // Fetch the actual image from the URL
      console.log(`[relay] Image ready. Downloading from URL...`);
      const imageResponse = await fetch(data.image_url);

      if (!imageResponse.ok) {
        console.error(`[relay] Failed to fetch image from URL: ${imageResponse.status}`);
        return res.status(imageResponse.status).json({ error: "Failed to download image" });
      }

      const imageBuffer = await imageResponse.arrayBuffer();
      const imageBase64 = Buffer.from(imageBuffer).toString("base64");

      // Update job store
      if (jobStore.has(image_id)) {
        jobStore.get(image_id).status = "completed";
        jobStore.get(image_id).completedAt = Date.now();
      }

      console.log(`[relay] Image downloaded and encoded. Size: ${imageBuffer.byteLength} bytes -> base64 length: ${imageBase64.length}`);

      return res.json({
        status: "completed",
        image: imageBase64,
        size_bytes: imageBuffer.byteLength,
      });
    } else if (status === "pending" || status === "processing") {
      return res.json({ status: "processing" });
    } else {
      console.error(`[relay] Unexpected status: ${status}`);
      return res.json({ status: status, error: data.error || "Unknown error" });
    }
  } catch (err) {
    console.error("[relay] Status check failed:", err);
    res.status(500).json({ error: String(err) });
  }
});

app.listen(PORT, () => {
  console.log(`Image Generation Relay listening on http://localhost:${PORT}`);
});
