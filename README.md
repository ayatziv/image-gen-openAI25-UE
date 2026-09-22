# 11 Labs Image Generation Relay (GPT Image 2.5)

Asynchronous image generation relay for **Unreal Engine 5** integration with **11 Labs' GPT Image 2.5** model.

This relay sits between UE5 and 11 Labs' Image API, handling the async polling workflow: submit job → poll status → download & base64-encode the result.

```
UE5 (VaRest, JSON)  --->  Local relay (Node.js)  --->  11 Labs Image API
        ^                                                      |
        |              [1] Submit job, get ID                 |
        |              [2] Poll /image-status                 |
        |              [3] Download & base64-encode          |
        |                  base64-wrapped JSON                |
        +------------------------------------------------------+
```

---

## Quick Start

### 1. Setup

```bash
# Install dependencies
npm install

# Copy and configure .env
cp .env.example .env
# Edit .env and add your 11 Labs API key:
#   ELEVENLABS_API_KEY=your_api_key_here
```

### 2. Run the relay

```bash
node relay.js
```

Expected output:
```
Image Generation Relay listening on http://localhost:3001
   Health: GET  http://localhost:3001/health
   Submit: POST http://localhost:3001/generate-image
   Status: GET  http://localhost:3001/image-status?image_id=<id>
```

### 3. Test it

```bash
# Submit an image generation job
curl -X POST http://localhost:3001/generate-image \
  -H "Content-Type: application/json" \
  -d '{
    "prompt":"a cybernetic owl perched on a neon sign, detailed textures, vibrant lighting",
    "model_id":"gpt-image-2.5-flare",
    "aspect_ratio":"16:9"
  }'

# Response: {"image_id": "image_xxx", "status": "submitted"}

# Check status (repeat every 2-3 seconds)
curl http://localhost:3001/image-status?image_id=image_xxx

# When ready: {"status": "completed", "image": "<base64>...", "size_bytes": 123456}
```

---

## API Endpoints

### `GET /health`
Liveness check for UE5.

**Response:**
```json
{"status":"ok","relay":"image-relay","version":"1.0.0","time":"..."}
```

### `POST /generate-image`
Submit an image generation job to 11 Labs.

**Body:**
```json
{
  "prompt": "a cybernetic owl perched on a neon sign",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "16:9"
}
```

**Parameters:**
- `prompt` (required): Detailed image description
- `model_id` (optional):
  - `gpt-image-2.5-flare` (default, ~10-15s)
  - `gpt-image-2.5-sunburst` (high-quality, ~20-30s)
- `aspect_ratio` (optional): `1:1` (default), `16:9`, `9:16`, etc.

**Response:**
```json
{"image_id": "image_xxx", "status": "submitted"}
```

### `GET /image-status?image_id=<id>`
Check the status of a generation job.

**Responses:**

Still processing:
```json
{"status": "processing"}
```

Completed:
```json
{
  "status": "completed",
  "image": "<base64-encoded-png>",
  "size_bytes": 123456
}
```

Error:
```json
{"status": "error", "error": "..."}
```

### `GET /jobs` (Debug)
List all tracked jobs.

---

## UE5 Blueprint Integration

### Step 1: Submit Generation Request

```
Get VaRest Subsystem
  → Construct Json Request (Verb: POST, Content Type: json)
  → Set URL: http://localhost:3001/generate-image
  → Construct Json Object
      Set String Field: "prompt"       = "<your image description>"
      Set String Field: "model_id"     = "gpt-image-2.5-flare"
      Set String Field: "aspect_ratio" = "16:9"
  → Set Request Object
  → Bind Event to On Request Complete
  → Execute Process Request

[In OnRequestComplete]
  → Get Response Object
  → Get String Field ("image_id")
  → **Store as ImageID variable** (for polling)
```

### Step 2: Poll for Completion

```
Delay (1-2 seconds)
  → Loop: Get /image-status?image_id=<ImageID>
  → If status = "processing" → wait and loop
  → If status = "completed"
      → Get String Field ("image")
      → Base64 Decode Data
      → Save Array to File ("generated_image.png")
  → If status = "error" → log and exit
```

---

## Requirements

- **Node.js** 14+
- **11 Labs Pro account** or higher
- **API key with Image & Video permissions** enabled
  - Dashboard → Settings → API Access → Image & Video

---

## Configuration

Edit `.env`:

```env
ELEVENLABS_API_KEY=your_api_key_here
PORT=3001
DEBUG=false
```

---

## Model Variants

| Model | Speed | Quality | Use Case |
|-------|-------|---------|----------|
| `gpt-image-2.5-flare` | Fast (10-15s) | Good | Real-time iteration |
| `gpt-image-2.5-sunburst` | Slower (20-30s) | Excellent | High-fidelity work |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| 402 "paid_plan_required" | Upgrade to Pro plan or higher |
| 401 "Unauthorized" | API key is wrong or expired — check `.env` |
| Image permissions error | Dashboard → Settings → API Access → Enable "Image & Video" |
| Polling times out | Image generation can take 15-30s — increase timeout in Blueprint |
| Image corrupted/tiny | Network issue during download — retry request |

---

## File Structure

```
.
├── relay.js              # Main relay server
├── package.json          # Dependencies (express, dotenv)
├── package-lock.json     # Lock file
├── .env                  # Configuration (never commit)
├── .env.example          # Configuration template
├── .gitignore            # Git ignore rules
└── README.md             # This file
```

---

## Development Notes

- The relay uses **in-memory job storage**. For production, use a database.
- Jobs are tracked with 11 Labs `image_id` as the key.
- Image URLs from 11 Labs are temporary—download immediately.
- All responses are JSON for VaRest compatibility.

---

## License

MIT

---

## Related Projects

- [generate-music-11lab](https://github.com/ayatziv/generate-music-11lab) — Music generation relay
