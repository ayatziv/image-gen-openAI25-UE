# Quick Test: Image Reference with input.jpg

Test the image reference feature using your actual input.jpg image.

---

## Setup

### 1. Start the Relay

```bash
cd "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE"
start image relay ue5.bat
```

Wait for:
```
Image Generation Relay listening on http://localhost:3001
```

### 2. Verify Health

```bash
curl http://localhost:3001/health
```

Expected response:
```json
{"status":"ok","relay":"image-relay","time":"..."}
```

---

## Test Steps

### Step 1: Read Base64 from File

The image has been converted to base64 and saved in:
```
test\input_base64.txt
```

**Get the base64 content:**
```bash
cd "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test"
type input_base64.txt
```

This will print the entire base64 string. **Copy it completely** (select all, Ctrl+C).

---

### Step 2: Create Test JSON

Create a file named `test_request.json` with:

```json
{
  "prompt": "enhance colors and add vibrant lighting, improve details",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "16:9",
  "image_data": "data:image/jpeg;base64,PASTE_BASE64_HERE"
}
```

**Replace `PASTE_BASE64_HERE`** with the base64 string from input_base64.txt

---

### Step 3: Submit Request

```bash
curl -X POST http://localhost:3001/generate-image-from-reference ^
  -H "Content-Type: application/json" ^
  -d @test_request.json
```

**Expected Response:**
```json
{
  "image_id": "img_abc123xyz",
  "status": "submitted"
}
```

✅ **Save the `image_id` value**

---

### Step 4: Poll for Completion

Replace `img_abc123xyz` with your actual image_id:

```bash
curl http://localhost:3001/image-status?image_id=img_abc123xyz
```

**While processing:**
```json
{"status":"processing"}
```

**Poll every 3-5 seconds** until you see:

```json
{
  "status": "completed",
  "image": "iVBORw0KGgoAAAANSUhEUgAA...",
  "size_bytes": 123456
}
```

⏱️ **Expected: 15-30 seconds**

---

### Step 5: Save Generated Image

Copy the `"image"` value (the base64 string).

Create a PowerShell script `save_image.ps1`:

```powershell
$base64 = "PASTE_IMAGE_BASE64_HERE"
$outputPath = "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test\output.jpg"

$imageBytes = [System.Convert]::FromBase64String($base64)
[System.IO.File]::WriteAllBytes($outputPath, $imageBytes)

Write-Host "✅ Image saved to: $outputPath"
Write-Host "Size: $([math]::Round((Get-Item $outputPath).Length / 1024, 2)) KB"
```

Run:
```bash
powershell -ExecutionPolicy Bypass -File save_image.ps1
```

---

### Step 6: View Result

```bash
# Windows - Open the generated image
start "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test\output.jpg"
```

---

## Quick Reference: One File to Use

**Files created for you:**

| File | Purpose |
|------|---------|
| `test\input.jpg` | Your source image (884 KB) |
| `test\input_base64.txt` | Base64 encoded version |
| `test_image_reference.ps1` | Automated PowerShell test |
| `test_image_reference.sh` | Automated bash test |
| `test\output.jpg` | Generated result (after test) |

---

## Automated Testing

If you have bash/PowerShell set up:

### Option A: PowerShell Script

```bash
cd "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE"
powershell -ExecutionPolicy Bypass -File test_image_reference.ps1
```

### Option B: Bash Script

```bash
cd "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE"
bash test_image_reference.sh
```

---

## Manual Test Commands (Copy-Paste)

### Health Check
```bash
curl http://localhost:3001/health
```

### List Files
```bash
dir "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test"
```

### Check Base64 Size
```bash
powershell -Command "(Get-Content 'test\input_base64.txt').Length"
```

### View Generated Image
```bash
start "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test\output.jpg"
```

---

## Success Criteria

✅ Image reference submission accepted (200 status)  
✅ Image ID returned  
✅ Polling returns "processing"  
✅ Polling returns "completed"  
✅ Base64 image data received  
✅ Decoded image is valid JPG  
✅ Can open and view generated image  

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Connection refused" | Relay not running - start it first |
| "Payload too large" | Base64 string might be corrupted - use fresh copy |
| "Processing" forever | Wait longer or increase max attempts |
| "No such file" | Check path: `test\input.jpg` exists |
| Image won't open | Base64 decoding failed - verify string |

---

## Next Step

Once you confirm the image generates successfully:
1. ✅ Test with image reference works
2. 👉 Build UE5 blueprints using `BLUEPRINT_IMAGE_REFERENCE.md`
3. 👉 Add file picker to select different images
4. 👉 Integrate into your game

