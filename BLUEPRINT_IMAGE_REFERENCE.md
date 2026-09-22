# UE5 Blueprint: Image Reference Generation

Complete guide for generating images from reference images using blueprints.

---

## Prerequisites

- VaRest plugin installed
- Relay running: `start image relay ue5.bat`
- `.env` configured with `ELEVENLABS_API_KEY`

---

## Overview: Image Reference Workflow

```
User uploads reference image
    ↓
Read image file to bytes
    ↓
Encode to base64
    ↓
Send to /generate-image-from-reference with prompt
    ↓
Get image_id
    ↓
Poll /image-status
    ↓
Download & display result
```

---

## Step 1: Create Image Reference Blueprint Actor

### Setup Variables

Create a new Actor Blueprint: `BP_ImageReferenceGenerator`

Add these variables:

| Variable | Type | Default | Purpose |
|----------|------|---------|---------|
| `RelayURL` | String | `http://localhost:3001` | Relay server |
| `Prompt` | String | | Generation prompt |
| `ModelID` | String | `gpt-image-2.5-flare` | Model variant |
| `AspectRatio` | String | `16:9` | Aspect ratio |
| `CurrentImageID` | String | | Active job ID |
| `IsPolling` | Boolean | false | Polling status |
| `PollDelay` | Float | 2.0 | Poll interval (seconds) |
| `MaxPollAttempts` | Integer | 60 | Max retries |
| `PollAttempts` | Integer | 0 | Current attempt |
| `SelectedImagePath` | String | | Reference image file path |
| `ReferenceImageBase64` | String | | Encoded image data |
| `GeneratedImageBase64` | String | | Result image (base64) |

---

## Step 2: Image File Selection

### Event: Browse for Image

**Blueprint Flow:**

```
Event: On Browse Button Click
    ↓
Open File Dialog
    ├─ Dialog Title: "Select Reference Image"
    ├─ File Types: *.png, *.jpg, *.jpeg
    ├─ Default Path: Documents
    ↓
Get Selected File Path
    ↓
[Set] SelectedImagePath = selected path
    ↓
Branch: Is Path Valid?
    ├─ TRUE:
    │  ├─ Print String: "Selected image: " + SelectedImagePath
    │  └─ Call: LoadImageFile (path)
    │
    └─ FALSE:
       └─ Print Error: "No valid file selected"
```

### Function: LoadImageFile

**Inputs:**
- `FilePath` (String)

**Blueprint Nodes:**

```
Function Start
    ↓
Open File For Read
    ├─ Filename: FilePath
    ├─ Output: File Handle
    ↓
Get File Size
    ├─ File Handle: FileHandle
    ├─ Output: FileSize
    ↓
Branch: FileSize > 0 && FileSize < 10485760 (10MB)
    ├─ TRUE:
    │  ├─ Read File To Array
    │  │  ├─ File Handle: FileHandle
    │  │  └─ Output: ByteArray
    │  ↓
    │  ├─ Close File
    │  ├─ Encode ByteArray to Base64
    │  ├─ [Set] ReferenceImageBase64 = base64_string
    │  ├─ Print "Image loaded: " + FileSize + " bytes"
    │  └─ Return Success
    │
    └─ FALSE:
       ├─ Print Error: "File too large or invalid"
       ├─ Close File
       └─ Return Failure
```

---

## Step 3: Submit Image with Prompt

### Function: SubmitImageFromReference

**Inputs:**
- `InPrompt` (String)
- `InModelID` (String, default: "gpt-image-2.5-flare")
- `InAspectRatio` (String, default: "16:9")

**Blueprint Flow:**

```
Function Start
    ↓
Branch: ReferenceImageBase64 is empty?
    ├─ TRUE:
    │  └─ Print Error: "No image loaded. Click 'Browse' first."
    │  └─ Return
    ↓
[Set] Prompt = InPrompt
[Set] ModelID = InModelID
[Set] AspectRatio = InAspectRatio
    ↓
Get VaRest Subsystem
    ↓
Construct VaRest Request Ext
    ├─ Target: VaRest Subsystem
    ├─ Verb: POST
    ├─ Content Type: application/json
    ├─ Return Value
    ↓
Set URL
    ├─ Target: Request
    ├─ URL: RelayURL + "/generate-image-from-reference"
    ↓
Construct VaRest JSON Object
    ├─ Return Value
    ↓
Set String Field
    ├─ Field Name: "prompt"
    ├─ String Value: Prompt
    ↓
Set String Field
    ├─ Field Name: "model_id"
    ├─ String Value: ModelID
    ↓
Set String Field
    ├─ Field Name: "aspect_ratio"
    ├─ String Value: AspectRatio
    ↓
Set String Field
    ├─ Field Name: "image_data"
    ├─ String Value: ReferenceImageBase64
    ↓
Set Request Object
    ├─ Target: Request
    ├─ Json Object: Constructed JSON
    ↓
Bind Event
    ├─ OnRequestComplete → HandleReferenceResponse
    ├─ OnRequestFail → HandleRequestFailed
    ↓
Execute Process Request
    ↓
Print String: "Image reference request submitted..."
```

### Event: HandleReferenceResponse

**Inputs:**
- `ResponseObject` (VaRest Response)

**Blueprint Flow:**

```
Event HandleReferenceResponse
    ↓
Get Response Object
    ├─ Target: ResponseObject
    └─ Return Value
    ↓
Branch: Response Status == 200 or 201?
    ├─ TRUE:
    │  ├─ Get String Field "image_id"
    │  ├─ [Set] CurrentImageID = image_id
    │  ├─ [Set] IsPolling = true
    │  ├─ [Set] PollAttempts = 0
    │  ├─ Print "Image submitted! ID: " + CurrentImageID
    │  ├─ Delay (1.0 second)
    │  └─ Call: PollForCompletion
    │
    └─ FALSE:
       ├─ Get String Field "error"
       ├─ Print Error: "Failed to submit: " + error
       └─ Return
```

---

## Step 4: Polling & Status Check

### Function: PollForCompletion

**Blueprint Flow:**

```
Function PollForCompletion
    ↓
Branch: IsPolling == false?
    └─ If TRUE: Return
    ↓
Branch: PollAttempts >= MaxPollAttempts?
    ├─ If TRUE:
    │  ├─ Print "Generation timeout (60 attempts)"
    │  ├─ [Set] IsPolling = false
    │  └─ Return
    ↓
Increment PollAttempts
    ↓
Get VaRest Subsystem
    ↓
Construct VaRest Request Ext
    ├─ Verb: GET
    ├─ Content Type: application/json
    ↓
Set URL
    ├─ URL: RelayURL + "/image-status?image_id=" + CurrentImageID
    ↓
Bind Event
    ├─ OnRequestComplete → HandlePollResponse
    ├─ OnRequestFail → HandlePollFailed
    ↓
Execute Process Request
```

### Event: HandlePollResponse

**Inputs:**
- `ResponseObject` (VaRest Response)

**Blueprint Flow:**

```
Event HandlePollResponse
    ↓
Get Response Object
    ↓
Get String Field "status"
    ↓
[Branch] status == "completed"
    ├─ TRUE:
    │  ├─ Get String Field "image"
    │  ├─ [Set] GeneratedImageBase64 = image
    │  ├─ [Set] IsPolling = false
    │  ├─ Print "Image generated successfully!"
    │  └─ Call: OnImageReady (GeneratedImageBase64)
    │
    ├─ FALSE → Branch status == "processing"
    │  ├─ TRUE:
    │  │  ├─ Print "Processing... (attempt " + PollAttempts + "/60)"
    │  │  ├─ Delay (PollDelay)
    │  │  └─ Call: PollForCompletion (loop)
    │  │
    │  └─ FALSE (ERROR):
    │     ├─ Get String Field "error"
    │     ├─ [Set] IsPolling = false
    │     └─ Print Error: "Generation failed: " + error
```

---

## Step 5: Save Generated Image

### Event: OnImageReady

**Inputs:**
- `ImageBase64` (String)

**Blueprint Flow:**

```
Event OnImageReady
    ↓
Base64 Decode Data
    ├─ Source: ImageBase64
    ├─ Output: ByteArray
    ↓
Get Project Content Directory
    ├─ Output: ContentPath
    ↓
Append (String)
    ├─ A: ContentPath
    ├─ B: "/../Saved/Screenshots/generated_from_reference.png"
    ├─ Output: FullPath
    ↓
Save Array To File
    ├─ Bytes: ByteArray
    ├─ File Path: FullPath
    ├─ Output: Success
    ↓
Branch: Success?
    ├─ TRUE:
    │  └─ Print "Image saved: " + FullPath
    │
    └─ FALSE:
       └─ Print Error: "Failed to save image"
```

---

## Step 6: UI Widget Setup

### Create Widget: WBP_ImageReferenceGenerator

**Widget Layout:**

```
┌─────────────────────────────────┐
│ Image Generation From Reference │
├─────────────────────────────────┤
│                                 │
│ [Browse Image] [Preview]        │
│                                 │
│ Selected: [image_path_text]     │
│                                 │
├─────────────────────────────────┤
│ Prompt Input:                   │
│ [_______________________________]│
│                                 │
│ Model: [Flare v Sunburst]      │
│ Aspect: [16:9 v]               │
│                                 │
│ [Generate from Reference]       │
│ [Cancel]                        │
├─────────────────────────────────┤
│ Status: Ready                   │
│ Progress: 0/60                  │
├─────────────────────────────────┤
│                                 │
│   [Generated Image Preview]     │
│   (Updates when ready)          │
│                                 │
└─────────────────────────────────┘
```

### Widget Event: Browse Button Clicked

```
On Browse Button Clicked
    ↓
Get Image Generator Reference
    ↓
Call: LoadImageFile (from BP_ImageReferenceGenerator)
    ↓
If Success:
    ├─ Update Text: "Image loaded: " + filename
    ├─ Show Preview of selected image
    └─ Enable "Generate" button
```

### Widget Event: Generate Button Clicked

```
On Generate Clicked
    ↓
Get Prompt Text: Input_Prompt
Get Model Selection: ComboBox_Model
Get Aspect Selection: ComboBox_Aspect
    ↓
Get Image Generator Reference
    ↓
Call: SubmitImageFromReference
    ├─ InPrompt: Input_Prompt
    ├─ InModelID: ComboBox_Model value
    ├─ InAspectRatio: ComboBox_Aspect value
    ↓
Update Status Text: "Processing..."
Disable Generate Button
Start Timer: 30 second timeout
```

---

## Complete Blueprint Event Graph

### In Level Blueprint:

```
Event Begin Play
    ↓
Spawn BP_ImageReferenceGenerator
    ├─ Location: (0, 0, 0)
    └─ Output: ImageGenRef
    ↓
Create Widget: WBP_ImageReferenceGenerator
    ├─ Output: WidgetRef
    ↓
Add to Viewport
    ├─ ZOrder: 100
    ↓
Bind Widget Events to ImageGenRef
    ├─ BrowseButton → LoadImage
    ├─ GenerateButton → SubmitImageFromReference
    ├─ CancelButton → StopGeneration
```

---

## Testing Workflow

### 1. **Start Relay**
```bash
start image relay ue5.bat
```

### 2. **Open UE5**
- Play (PIE)
- Widget appears with "Browse" button

### 3. **Select Image**
- Click "Browse Image"
- Select a PNG/JPG from disk
- See "Image loaded: X bytes"

### 4. **Enter Prompt**
- Type: "add blue sky and clouds"
- Select model: "Flare"
- Select aspect: "16:9"

### 5. **Generate**
- Click "Generate from Reference"
- Watch status: "Processing... (1/60)"
- Wait 15-30 seconds
- Image saved automatically

### 6. **Expected Output**
```
[ImageGen] Image reference request submitted...
[ImageGen] Processing... (1/60)
[ImageGen] Processing... (5/60)
...
[ImageGen] Image generated successfully!
Image saved: Saved/Screenshots/generated_from_reference.png
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "No image loaded" error | Click "Browse" and select an image first |
| 400 Bad Request | Ensure image is valid PNG/JPG, not corrupted |
| 413 Payload Too Large | Image > 10MB, resize or compress first |
| Generation timeout | Increase MaxPollAttempts or PollDelay |
| "Failed to save image" | Check Saved/Screenshots folder exists |
| Relay connection error | Ensure relay running on port 3001 |

---

## Advanced: Image Preview in Widget

To show selected image in widget:

```
After Image Loaded:
    ↓
Create Texture 2D from ByteArray
    ├─ Save ByteArray to Texture Asset
    └─ Output: Texture
    ↓
Set Image Widget Source
    ├─ Target: PreviewImage_Brush
    ├─ Texture: Newly created texture
```

---

## API Reference

### Endpoint: POST /generate-image-from-reference

**Request:**
```json
{
  "prompt": "add blue sky and clouds",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "16:9",
  "image_data": "data:image/png;base64,iVBORw0KGgo..."
}
```

**Response:**
```json
{
  "image_id": "img_xyz123",
  "status": "submitted"
}
```

**Status Check:** `GET /image-status?image_id=img_xyz123`

**When Ready:**
```json
{
  "status": "completed",
  "image": "iVBORw0KGgo...",
  "size_bytes": 123456
}
```

---

## Summary

✅ Select reference image file  
✅ Encode to base64 in blueprint  
✅ Send with prompt to `/generate-image-from-reference`  
✅ Poll `/image-status` until ready  
✅ Save base64-decoded image  
✅ Display in widget  

Ready to create variations from reference images! 🎨

