# Complete UE5 Blueprint Integration Guide
## Image Generation Relay → Texture Display

---

## Overview

This guide shows how to:
1. Call the relay server from UE5
2. Get base64 image data
3. Convert to texture
4. Display in UI

---

## Prerequisites

- **VaRest Plugin** installed in UE5
- **Relay server** running on `http://localhost:3001`
- **UI Canvas** to display the image

---

## Step 1: Create Blueprint Function - Generate Image

### Create a new Blueprint Function Library or Actor Blueprint

**Function Name:** `GenerateImageFromPrompt`

**Inputs:**
- `Prompt` (String) - e.g., "a red cube"
- `AspectRatio` (String) - e.g., "1:1"

**Outputs:**
- `ImageID` (String)
- `Success` (Boolean)

### Blueprint Nodes:

```
1. Create HTTP Request (VaRest)
   ├─ URL: "http://localhost:3001/generate-image"
   ├─ Verb: POST
   ├─ Header: "Content-Type" = "application/json"
   └─ Body JSON:
       {
         "prompt": "[Prompt]",
         "model_id": "gpt-image-2.5-flare",
         "aspect_ratio": "[AspectRatio]"
       }

2. Execute HTTP Request
   ├─ On Complete: Parse Response
   └─ On Error: Return Failure

3. Parse JSON Response
   ├─ Get "image_id" field
   └─ Return ImageID + Success=true
```

---

## Step 2: Create Blueprint Function - Poll Status

### Function Name: `PollImageStatus`

**Inputs:**
- `ImageID` (String)
- `MaxAttempts` (Integer, default 60)
- `PollInterval` (Float, default 2.0 seconds)

**Outputs:**
- `IsComplete` (Boolean)
- `ImageData` (String) - base64 encoded
- `ErrorMessage` (String)

### Blueprint Logic:

```
Loop (for MaxAttempts):
├─ Wait PollInterval seconds
├─ GET http://localhost:3001/image-status?image_id=[ImageID]
├─ Parse Response:
│  ├─ If status == "completed"
│  │  └─ Get "image_data" field → Return Success
│  ├─ If status == "processing"
│  │  └─ Continue loop
│  └─ If error
│     └─ Return Error
└─ After MaxAttempts → Return Timeout Error
```

### Node Breakdown:

```
HTTP Get Request:
├─ URL: "http://localhost:3001/image-status"
├─ Query Parameter: "image_id=[ImageID]"
└─ Method: GET

JSON Parsing:
├─ Response: Parse as JSON
├─ Extract: status
├─ Extract: image_data (base64)
└─ Extract: error (if present)

Loop Control:
├─ Use "Do N" loop or "WhileLoop"
├─ Increment counter each iteration
├─ Check status and break conditions
└─ Handle timeout
```

---

## Step 3: Convert Base64 to Texture

### Function Name: `CreateTextureFromBase64`

**Inputs:**
- `Base64Data` (String)

**Outputs:**
- `ResultTexture` (Texture2D)
- `Success` (Boolean)

### Blueprint Nodes:

```
1. Decode Base64 String
   ├─ Input: Base64Data
   ├─ Output: Byte Array
   └─ Note: Use "Conv String to Bytes" with base64 conversion

2. Create Texture from Bytes
   ├─ Input: Byte Array (image data)
   ├─ Method: Use "Texture2D" constructor
   ├─ Format: RGBA (automatic detection)
   └─ Output: Texture2D object

3. Alternative: Load Image from Memory
   ├─ Use "LoadImageFromMemory" node
   ├─ Input: Byte Array
   └─ Output: Texture2D
```

### Detailed Node Chain:

```
Input: Base64Data String
   ↓
[String] Convert String to Base64 Decode
   ↓
Output: Byte Array
   ↓
[Create Texture from Binary Data]
   ├─ Input Bytes
   ├─ Width: Auto-detect
   ├─ Height: Auto-detect
   └─ Format: Automatic
   ↓
Output: Texture2D
```

---

## Step 4: Display Texture in UI

### Setup Image Widget

```
UI Canvas (Widget Blueprint):
├─ Image Widget
│  ├─ Brush → Texture Asset → [ResultTexture]
│  └─ Size Mode: Fill Screen / Scale to Size
│
└─ Text Widget (Status)
   ├─ Display: "Generating..."
   └─ Update on completion
```

### Blueprint Event Graph:

```
Event: Button "Generate Image" Clicked
   ↓
1. Set Status Text → "Generating image..."
2. Call GenerateImageFromPrompt
   ├─ On Success:
   │  └─ ImageID = returned value
   │
   └─ On Failure:
      └─ Show Error Message

3. Call PollImageStatus (ImageID)
   ├─ On Complete:
   │  ├─ Get Base64Data from response
   │  ├─ Call CreateTextureFromBase64
   │  ├─ Update Image Widget Texture
   │  └─ Set Status Text → "Complete!"
   │
   └─ On Error:
      └─ Show Error Message
```

---

## Complete Call Flow Diagram

```
User Input (Button Click)
         ↓
   Generate Image Request
         ↓
   Relay Server (3001)
         ↓
   Job ID Returned
         ↓
   Poll Status (2sec intervals)
         ↓
   Status Complete
         ↓
   Get Base64 Image Data
         ↓
   Decode Base64 → Byte Array
         ↓
   Create Texture from Bytes
         ↓
   Display in UI Widget
         ↓
   Done ✅
```

---

## Example Blueprint Variable Setup

```
Variables:
├─ CurrentImageID (String)
├─ CurrentBase64Data (String)
├─ GeneratedTexture (Texture2D)
├─ IsGenerating (Boolean)
└─ LastError (String)
```

---

## HTTP Request/Response Examples

### Generate Image Request:
```json
POST http://localhost:3001/generate-image
Content-Type: application/json

{
  "prompt": "a red cube with metallic finish",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "1:1"
}
```

### Generate Image Response:
```json
{
  "image_id": "n22BP0FN1RTqwTpfmjtg",
  "status": "submitted"
}
```

### Status Poll Request:
```
GET http://localhost:3001/image-status?image_id=n22BP0FN1RTqwTpfmjtg
```

### Status Poll Response (Processing):
```json
{
  "status": "processing",
  "image_id": "n22BP0FN1RTqwTpfmjtg"
}
```

### Status Poll Response (Complete):
```json
{
  "status": "completed",
  "image_id": "n22BP0FN1RTqwTpfmjtg",
  "image_data": "iVBORw0KGgoAAAANSUhEUgAAA..."
}
```

---

## Troubleshooting

### "Cannot connect to relay"
- Check relay is running: `start image relay ue5.bat`
- Verify localhost:3001 is accessible
- Check firewall settings

### "Invalid base64 data"
- Verify image_data field contains full base64 string
- Check base64 decoding node settings
- Ensure response is complete (not truncated)

### "Texture creation failed"
- Base64 data might be corrupted
- Image format might not be supported (use JPG/PNG)
- Try different image size

### "Polling timeout"
- Image generation takes longer than expected
- Increase MaxAttempts in PollImageStatus
- Check relay logs for generation errors

---

## Advanced: Using Reference Images

### For Image-to-Image Generation:

1. **Load reference image** from disk or widget
2. **Convert to base64** (same process reversed)
3. **Send with image_data field:**

```json
POST http://localhost:3001/generate-image-from-reference

{
  "prompt": "enhance with vibrant colors",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "16:9",
  "image_data": "data:image/jpeg;base64,iVBORw0KGgo..."
}
```

---

## Performance Tips

- **Async calls**: Use VaRest's async nodes to avoid freezing UI
- **Timeout handling**: Set reasonable MaxAttempts (60 = ~2 minutes)
- **Error recovery**: Store ImageID to retry if interrupted
- **Caching**: Save generated textures to avoid regenerating
- **Thread-safe**: Use proper variable synchronization

---

## Next Steps

1. Create the blueprint functions from this guide
2. Test with a simple button + image widget
3. Add error handling and UI feedback
4. Integrate with your game logic
5. Cache results to avoid redundant requests

---

Generated for Image Gen UE5 Relay 🚀

