# Testing Image Reference Generation - Complete Guide

Step-by-step testing from scratch.

---

## Phase 1: Prerequisites Check

### 1.1 Verify Relay is Running

```bash
# Option A: Start via batch file
start image relay ue5.bat

# Option B: Start manually
node "image gen openai 2_5 via 11lab  ue relay.js"
```

**Expected Output:**
```
Image Generation Relay listening on http://localhost:3001
```

### 1.2 Check Health Endpoint

```bash
curl http://localhost:3001/health
```

**Expected Response:**
```json
{
  "status": "ok",
  "relay": "image-relay",
  "time": "2026-09-22T10:30:00.000Z"
}
```

✅ If successful: Relay is running and accessible

❌ If failed: Check that port 3001 is not blocked

---

## Phase 2: Test Text-to-Image (Baseline)

Test the original endpoint first to confirm relay works.

### 2.1 Submit Text Prompt

```bash
curl -X POST http://localhost:3001/generate-image \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a red apple on a table",
    "model_id": "gpt-image-2.5-flare",
    "aspect_ratio": "16:9"
  }'
```

**Expected Response:**
```json
{
  "image_id": "img_abc123xyz",
  "status": "submitted"
}
```

✅ Save the `image_id` for next step

### 2.2 Poll for Completion

```bash
# Replace img_abc123xyz with your actual image_id
curl http://localhost:3001/image-status?image_id=img_abc123xyz
```

**Responses you'll see:**

**While processing:**
```json
{
  "status": "processing"
}
```

**When ready:**
```json
{
  "status": "completed",
  "image": "iVBORw0KGgoAAAANSUhEUgAA...",
  "size_bytes": 123456
}
```

✅ If you get "completed": Text-to-image works! Proceed to Phase 3.

❌ If timeout: Increase retry attempts or wait longer

---

## Phase 3: Prepare Reference Image

### 3.1 Get a Test Image

Use any image you have, or download a sample:

```bash
# Windows: Use any image from Pictures or Documents
# Location: C:\Users\YourName\Pictures\test_image.jpg
```

**Requirements:**
- Format: PNG or JPG
- Size: < 10 MB
- Resolution: Any (will be resized by 11 Labs)

### 3.2 Convert Image to Base64

**Windows PowerShell:**
```powershell
$imagePath = "C:\Users\amir_desktop\Pictures\test_image.jpg"
$imageBytes = [System.IO.File]::ReadAllBytes($imagePath)
$base64 = [System.Convert]::ToBase64String($imageBytes)
Write-Output $base64 | clip  # Copies to clipboard
```

**Or use online tool:**
- https://www.base64encode.org/
- Upload your image → Copy base64 output

**Or create test image:**
```powershell
# Create a simple test PNG (1x1 pixel)
$base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
```

---

## Phase 4: Test Image Reference Endpoint

### 4.1 Submit Image with Prompt

```bash
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "same scene but with blue sky and clouds",
    "model_id": "gpt-image-2.5-flare",
    "aspect_ratio": "16:9",
    "image_data": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  }'
```

**Replace the `image_data` value with your actual base64 string.**

**Expected Response:**
```json
{
  "image_id": "img_ref_xyz789",
  "status": "submitted"
}
```

✅ Success! Image reference accepted

### 4.2 Relay Console Output

You should see in relay console:
```
[relay] Image generation from reference: prompt="same scene but with..." model=gpt-image-2.5-flare aspect=16:9 image_size=456789 bytes
[relay] Image job from reference submitted. ID: img_ref_xyz789
```

### 4.3 Poll for Image

```bash
# Use the image_id from the response
curl http://localhost:3001/image-status?image_id=img_ref_xyz789
```

**Wait 15-30 seconds, then poll again:**

```bash
# Poll every 3-5 seconds
for i in {1..20}; do
  echo "Attempt $i:"
  curl http://localhost:3001/image-status?image_id=img_ref_xyz789
  echo ""
  sleep 3
done
```

**When ready:**
```json
{
  "status": "completed",
  "image": "iVBORw0KGgoAAAANSUhEUgAA...",
  "size_bytes": 234567
}
```

✅ **Image reference generation works!**

---

## Phase 5: Save & Verify Result

### 5.1 Decode Base64 to Image

**Windows PowerShell:**
```powershell
$base64 = "iVBORw0KGgoAAAANSUhEUgAA..."  # From response
$imageBytes = [System.Convert]::FromBase64String($base64)
[System.IO.File]::WriteAllBytes("C:\temp\generated_image.png", $imageBytes)
echo "Image saved to C:\temp\generated_image.png"
```

**Or online:**
- https://www.base64decode.org/
- Paste base64 → Download image

### 5.2 Open & Inspect

```bash
# Windows
start C:\temp\generated_image.png
```

✅ Verify the generated image looks reasonable

---

## Phase 6: Error Testing

Test error cases to ensure error handling works.

### 6.1 Missing Prompt

```bash
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d '{
    "model_id": "gpt-image-2.5-flare",
    "image_data": "data:image/png;base64,iVBORw0KGgo..."
  }'
```

**Expected: 400 Error**
```json
{
  "error": "Missing prompt in request body."
}
```

✅ Correct error handling

### 6.2 Missing Image Data

```bash
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "test prompt",
    "model_id": "gpt-image-2.5-flare"
  }'
```

**Expected: 400 Error**
```json
{
  "error": "Missing image_data (base64 encoded image) in request body."
}
```

✅ Correct error handling

### 6.3 Invalid Base64

```bash
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "test",
    "image_data": "not_valid_base64!!!"
  }'
```

**Expected: Error from 11 Labs (422 or 400)**
```json
{
  "error": "..."
}
```

✅ Error passed through correctly

### 6.4 Invalid Image ID Polling

```bash
curl http://localhost:3001/image-status?image_id=img_nonexistent
```

**Expected: 404 or error from 11 Labs**

---

## Phase 7: Performance Testing

### 7.1 Measure Response Times

**Start time:**
```bash
echo Start: $(date)
```

**Submit request, note response time (usually < 500ms):**
```bash
curl -X POST http://localhost:3001/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "test",
    "model_id": "gpt-image-2.5-flare",
    "image_data": "data:image/png;base64,..."
  }'
echo "Response received: $(date)"
```

**Generation time (usually 15-30 seconds):**
```bash
# Note when you get "completed" status
# Typical: 15s (flare) - 30s (sunburst)
```

### 7.2 Load Testing

**Send multiple requests:**
```bash
for i in {1..5}; do
  echo "Request $i"
  curl -X POST http://localhost:3001/generate-image-from-reference \
    -H "Content-Type: application/json" \
    -d "{...}" &
done
wait
```

✅ Ensure relay handles concurrent requests

---

## Phase 8: Real-World Test

### 8.1 Create Simple Test Script

**test_image_ref.sh** (or .bat for Windows):

```bash
#!/bin/bash

# Configuration
RELAY_URL="http://localhost:3001"
TEST_IMAGE="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
PROMPT="variation with different colors"
MODEL="gpt-image-2.5-flare"
ASPECT="16:9"

echo "=== Testing Image Reference Generation ==="
echo ""

# Submit
echo "[1/4] Submitting request..."
RESPONSE=$(curl -s -X POST $RELAY_URL/generate-image-from-reference \
  -H "Content-Type: application/json" \
  -d "{
    \"prompt\": \"$PROMPT\",
    \"model_id\": \"$MODEL\",
    \"aspect_ratio\": \"$ASPECT\",
    \"image_data\": \"$TEST_IMAGE\"
  }")

IMAGE_ID=$(echo $RESPONSE | grep -o '"image_id":"[^"]*' | cut -d'"' -f4)
echo "Image ID: $IMAGE_ID"
echo ""

# Poll
echo "[2/4] Polling for completion..."
ATTEMPT=0
while [ $ATTEMPT -lt 60 ]; do
  STATUS=$(curl -s "$RELAY_URL/image-status?image_id=$IMAGE_ID" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
  
  if [ "$STATUS" = "completed" ]; then
    echo "Generation complete!"
    break
  fi
  
  ATTEMPT=$((ATTEMPT + 1))
  echo "Attempt $ATTEMPT: $STATUS"
  sleep 2
done
echo ""

# Retrieve
echo "[3/4] Retrieving image..."
IMAGE_DATA=$(curl -s "$RELAY_URL/image-status?image_id=$IMAGE_ID" | grep -o '"image":"[^"]*' | cut -d'"' -f4)
echo "Image data size: ${#IMAGE_DATA} bytes"
echo ""

# Save
echo "[4/4] Saving image..."
echo "$IMAGE_DATA" | base64 -d > generated_image.png
echo "✅ Image saved to: generated_image.png"
```

**Run test:**
```bash
bash test_image_ref.sh
```

---

## Checklist: Complete Testing

- [ ] **Phase 1**: Health check passing
- [ ] **Phase 2**: Text-to-image working (baseline)
- [ ] **Phase 3**: Have test image ready
- [ ] **Phase 4**: Image reference endpoint accepts request
- [ ] **Phase 4**: Image ID returned successfully
- [ ] **Phase 4**: Polling returns "processing"
- [ ] **Phase 4**: Polling returns "completed" with image data
- [ ] **Phase 5**: Base64 decoded to valid PNG/JPG
- [ ] **Phase 6**: Error cases handled correctly
- [ ] **Phase 7**: Response times reasonable (< 500ms submit, 15-30s gen)
- [ ] **Phase 8**: Full test script runs successfully

---

## Expected Times

| Step | Time |
|------|------|
| Health check | < 100ms |
| Submit request | < 500ms |
| Generation (flare) | 10-20s |
| Generation (sunburst) | 20-30s |
| Poll response | < 500ms |
| Image download | 1-3s |
| Base64 decode | < 100ms |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Connection refused | Check relay is running on port 3001 |
| "Missing image_data" | Ensure image_data field is in JSON |
| "Invalid base64" | Verify base64 string is valid (no corruption) |
| "Payload too large" | Reduce image size or compress before encoding |
| "Processing" forever | Generation timeout - image too large/complex |
| Generated image is wrong | 11 Labs API might not support that variation |
| Relay crashes | Check Node.js version compatibility |

---

## Success Criteria

✅ **All of these must pass:**
1. Health endpoint responds
2. Text-to-image works
3. Image reference accepted with 200/201 status
4. Image ID returned
5. Polling eventually returns "completed"
6. Base64 image data received and valid
7. Decoded image is valid PNG/JPG
8. Error handling works for bad requests

**If all pass: Image reference feature is working! 🎉**

---

## Next: UE5 Blueprint Testing

Once CLI testing passes:
1. Build blueprints following `BLUEPRINT_IMAGE_REFERENCE.md`
2. Test file picker
3. Test base64 encoding
4. Test JSON submission
5. Test polling in UE5
6. Verify saved images in `Saved/Screenshots/`

