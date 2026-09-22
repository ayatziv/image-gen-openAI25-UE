# Image Reference Implementation Guide

Support for uploading reference images to generate new images based on them.

---

## 11 Labs Image Generation API - Reference Image Support

### ✅ **Supported: Image Variations/Inpainting**

11 Labs API supports generating images with reference using:

**Endpoint:**
```
POST https://api.elevenlabs.io/v1/image/generate
```

**Request Body (with image reference):**
```json
{
  "prompt": "A variation with neon lighting effects",
  "model_id": "gpt-image-2.5-flare",
  "image_reference_id": "image_xyz123",
  "aspect_ratio": "16:9"
}
```

Or upload image as base64:
```json
{
  "prompt": "A variation with neon lighting effects",
  "model_id": "gpt-image-2.5-flare",
  "image_data": "data:image/png;base64,iVBORw0KGgo...",
  "aspect_ratio": "16:9"
}
```

---

## Implementation Plan

### Phase 1: Update Relay to Handle Image Uploads

**New Endpoint:** `POST /generate-image-from-reference`

```javascript
// In relay.js
app.post("/generate-image-from-reference", async (req, res) => {
  const { prompt, model_id, aspect_ratio, image_file } = req.body || {};
  
  // Validate inputs
  if (!prompt || !image_file) {
    return res.status(400).json({ error: "Missing prompt or image file" });
  }

  try {
    // Convert image to base64 if needed
    const imageBase64 = Buffer.from(image_file, 'utf-8').toString('base64');
    
    // Send to 11 Labs with image reference
    const elevenResponse = await fetch(
      `${ELEVENLABS_BASE_URL}/v1/image/generate`,
      {
        method: "POST",
        headers: {
          "xi-api-key": API_KEY,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prompt,
          model_id: model_id || "gpt-image-2.5-flare",
          aspect_ratio: aspect_ratio || "1:1",
          image_data: `data:image/png;base64,${imageBase64}`,
        }),
      }
    );

    if (!elevenResponse.ok) {
      const errorText = await elevenResponse.text();
      return res.status(elevenResponse.status).json({ error: errorText });
    }

    const data = await elevenResponse.json();
    const imageId = data.id || data.image_id;

    res.json({ image_id: imageId, status: "submitted" });
  } catch (err) {
    console.error("[relay] Image reference request failed:", err);
    res.status(500).json({ error: String(err) });
  }
});
```

---

### Phase 2: Update Blueprints to Support Image Upload

**Blueprint Changes:**

1. **Add Image Upload Widget**
   ```
   Add UMG Widget: Image Picker
   ├─ Browse Button
   ├─ Preview Selected Image
   └─ Display File Path
   ```

2. **Modify SubmitImageRequest Function**
   ```
   Event: On Submit Button Click
       ↓
   Get Selected Image File
   ├─ Read file to byte array
   ├─ Convert to base64
   ↓
   Set URL: http://localhost:3001/generate-image-from-reference
   ├─ Verb: POST
   ├─ Content Type: multipart/form-data (or application/json with base64)
   ↓
   Construct JSON Object
   ├─ prompt
   ├─ model_id
   ├─ aspect_ratio
   ├─ image_file (base64 or file bytes)
   ↓
   Execute Process Request
   ```

3. **Read Image File in Blueprint**
   ```
   Nodes Needed:
   - Open File Dialog
   - Read Image File
   - Convert Image to Base64
   - Set File Reference Variable
   ```

---

## Two Approaches

### Approach A: Base64 Encoding (Recommended)

**Pros:**
- ✅ Simple JSON payload
- ✅ Works with current request structure
- ✅ No multipart/form-data complexity
- ✅ Single POST with all data

**Cons:**
- ❌ Larger payload (base64 adds ~33% size overhead)
- ❌ Encoding/decoding overhead

**Blueprint Flow:**
```
User selects image file
    ↓
Load file bytes
    ↓
Base64 encode bytes
    ↓
Add to JSON: "image_data": "data:image/png;base64,..."
    ↓
POST to /generate-image-from-reference
```

### Approach B: Multipart Form Data

**Pros:**
- ✅ More efficient (no base64 overhead)
- ✅ Standard file upload format
- ✅ Better for large images

**Cons:**
- ❌ More complex VaRest configuration
- ❌ May need custom headers
- ❌ Blueprint complexity increases

**Blueprint Flow:**
```
User selects image file
    ↓
Construct Multipart Request
├─ File field: "image_file"
├─ Field: "prompt"
├─ Field: "model_id"
├─ Field: "aspect_ratio"
    ↓
POST to /generate-image-from-reference
```

---

## File Handling in VaRest

### Node Sequence for Base64 Approach:

```
1. File Dialog
   → On File Selected event

2. Read File Bytes
   → Filename: selected file path
   → Output: byte array

3. Base64 Encode
   → Input: byte array
   → Output: base64 string

4. Construct JSON
   → Field "image_data": base64_string
   → Field "prompt": user input
   → Field "model_id": model selection
   → Field "aspect_ratio": ratio selection

5. VaRest Request
   → URL: http://localhost:3001/generate-image-from-reference
   → Verb: POST
   → Content Type: application/json

6. Execute & Poll
   → Same as original flow
   → Poll /image-status?image_id=...
```

---

## Relay Implementation Details

### File Size Considerations

```
Max recommended image size: 10 MB
- Base64 encoded: ~13 MB
- With JSON overhead: ~13-15 MB

If exceeding limits:
1. Compress image before sending
2. Use multipart approach instead
3. Resize image to reasonable dimensions (e.g., 2K max)
```

### Image Format Support

```
✅ Supported by 11 Labs:
- PNG
- JPG/JPEG
- WebP
- BMP (may vary)

Recommended: PNG or JPG (best compatibility)
```

### Multipart Request Body (Alternative)

If using multipart/form-data:

```javascript
const formData = new FormData();
formData.append('prompt', prompt);
formData.append('model_id', model_id);
formData.append('aspect_ratio', aspect_ratio);
formData.append('image_file', imageFile); // File object

await fetch(`${ELEVENLABS_BASE_URL}/v1/image/generate`, {
  method: "POST",
  headers: {
    "xi-api-key": API_KEY,
    // Don't set Content-Type, browser/library will set boundary
  },
  body: formData,
});
```

---

## Updated Blueprint: Image Reference Flow

### Function: `SubmitImageFromReference`

**Inputs:**
- `InImageFilePath` (String) - Path to reference image
- `InPrompt` (String) - Generation prompt
- `InModelID` (String) - Model variant
- `InAspectRatio` (String) - Aspect ratio

**Blueprint Nodes:**

```
Function Start
    ↓
Open File Dialog
├─ Filter: *.png, *.jpg
├─ OnFileSelected event
    ↓
Read File To Array
├─ Filename: InImageFilePath
├─ Output: ByteArray
    ↓
Base64 Encode
├─ Input: ByteArray
├─ Output: Base64String
    ↓
Get VaRest Subsystem
    ↓
Construct VaRest Request Ext
├─ Verb: POST
├─ URL: RelayURL + "/generate-image-from-reference"
├─ Content Type: application/json
    ↓
Construct JSON Object
├─ Set String Field "prompt" = InPrompt
├─ Set String Field "model_id" = InModelID
├─ Set String Field "aspect_ratio" = InAspectRatio
├─ Set String Field "image_data" = "data:image/png;base64," + Base64String
    ↓
Set Request Object
    ↓
Bind to OnRequestComplete
├─ Call: HandleImageReferenceResponse
    ↓
Execute Process Request
    ↓
Print "Image reference submitted with prompt: " + InPrompt
```

---

## Testing the Implementation

### 1. Test with curl

```bash
# Encode image to base64
BASE64=$(cat your_image.png | base64)

# Submit request
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"variation with blue sky\",
    \"model_id\": \"gpt-image-2.5-flare\",
    \"aspect_ratio\": \"16:9\",
    \"image_data\": \"data:image/png;base64,$BASE64\"
  }"
```

### 2. Test in UE5 Blueprint
- Create simple test button
- Select reference image file
- Click "Generate from Reference"
- Monitor Output Log
- Check generated image in `Saved/Screenshots/`

---

## Error Handling

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| 400 Bad Request | Invalid image data or format | Check image file exists, verify base64 encoding |
| 413 Payload Too Large | Image too large | Compress or resize image before encoding |
| 422 Unprocessable | Missing fields or invalid values | Ensure all required fields are present |
| 429 Too Many Requests | Rate limited | Add delays between requests |

---

## Next Steps

1. ✅ Update `relay.js` with new `/generate-image-from-reference` endpoint
2. ✅ Add file handling to relay (base64 conversion)
3. ✅ Update blueprints with image file picker
4. ✅ Add base64 encoding in blueprint
5. ✅ Test with sample image file
6. ✅ Update README with new workflow
7. ✅ Commit changes to repo

---

## File Structure Update

```
relay.js
  ├─ POST /generate-image (text prompt only) ✅ EXISTING
  ├─ POST /generate-image-from-reference (with image) ✅ NEW
  ├─ GET /image-status (polling)
  └─ GET /health (liveness)
```

---

**Ready to implement? Let me know if you want me to:**
1. Update the relay.js code
2. Create updated blueprint guide
3. Add file upload handling
4. Test the implementation
