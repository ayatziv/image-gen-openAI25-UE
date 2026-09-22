# UE5 Blueprint Integration Guide

Complete step-by-step guide to integrate the Image Generation Relay with Unreal Engine 5 using blueprints.

---

## Prerequisites

1. **VaRest Plugin** installed in your UE5 project
   - In Editor: `Edit` → `Plugins` → Search "VaRest" → Install
   
2. **Relay running** on `http://localhost:3001`
   ```bash
   node "image gen openai 2_5 via 11lab  ue relay.js"
   ```

3. **Basic Blueprint knowledge** (events, variables, loops)

---

## Overview: The 3-Step Workflow

```
[1] Submit Job         [2] Poll Status        [3] Get Image
   POST /generate-image    GET /image-status    base64 decode
   ↓                       ↓                      ↓
Send prompt      →    Check if ready   →   Download & decode
Get image_id     →    Wait & retry     →   Save/display
```

---

## Step 1: Create the Main BP Actor

### 1.1 Create New Blueprint Actor

```
Right-click Content Browser → Blueprint Class
Parent Class: Actor
Name: BP_ImageGenerator
```

### 1.2 Add Variables

In the Blueprint, add these variables:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `RelayURL` | String | `http://localhost:3001` | Relay server URL |
| `Prompt` | String | | Image description |
| `ModelID` | String | `gpt-image-2.5-flare` | Model variant |
| `AspectRatio` | String | `16:9` | Image aspect ratio |
| `CurrentImageID` | String | | ID of submitted job |
| `IsPolling` | Boolean | false | Polling active flag |
| `PollDelay` | Float | 2.0 | Seconds between polls |
| `MaxPollAttempts` | Integer | 60 | Max retries (2 min total) |
| `PollAttempts` | Integer | 0 | Current attempt count |
| `GeneratedImageBase64` | String | | Result image (base64) |

---

## Step 2: Blueprint - Submit Image Request

### Function: `SubmitImageRequest`

**Inputs:**
- `InPrompt` (String)
- `InModelID` (String, default: "gpt-image-2.5-flare")
- `InAspectRatio` (String, default: "16:9")

**Blueprint Flow:**

```
Event/Function Start
    ↓
[Set] Prompt = InPrompt
[Set] ModelID = InModelID
[Set] AspectRatio = InAspectRatio
    ↓
Get VaRest Subsystem
    ↓
Construct VaRest Request
    ├─ Verb: POST
    ├─ URL: RelayURL + "/generate-image"
    ├─ Content Type: application/json
    ↓
Construct JSON Object
    ├─ Set Field "prompt" = Prompt
    ├─ Set Field "model_id" = ModelID
    ├─ Set Field "aspect_ratio" = AspectRatio
    ↓
[Set] VaRest Request Object
    ↓
Bind to "On Request Complete"
    ├─ Call: HandleSubmitResponse (ResponseObject)
    ↓
Execute (Execute Process Request)
    ↓
Print String "Image request submitted..."
```

### Event: `HandleSubmitResponse`

**Inputs:**
- `ResponseObject` (VaRest Response)

**Blueprint Flow:**

```
Event HandleSubmitResponse
    ↓
[Get] Response Object
    ├─ If Status != 200
    │  └─ Print Error & Return
    ↓
Get String Field "image_id"
    ↓
[Set] CurrentImageID = image_id
[Set] IsPolling = true
[Set] PollAttempts = 0
    ↓
Delay (1.0 second)
    ↓
Call: PollForCompletion
```

---

## Step 3: Blueprint - Poll Status

### Function: `PollForCompletion`

**Blueprint Flow:**

```
Function PollForCompletion
    ↓
[Check] IsPolling == false
    └─ If true: Return (stop polling)
    ↓
[Check] PollAttempts >= MaxPollAttempts
    └─ If true:
       ├─ Print "Polling timeout!"
       ├─ Set IsPolling = false
       └─ Return
    ↓
Increment PollAttempts
    ↓
Get VaRest Subsystem
    ↓
Construct VaRest Request
    ├─ Verb: GET
    ├─ URL: RelayURL + "/image-status?image_id=" + CurrentImageID
    ├─ Content Type: application/json
    ↓
Bind to "On Request Complete"
    ├─ Call: HandlePollResponse (ResponseObject)
    ↓
Execute (Execute Process Request)
```

### Event: `HandlePollResponse`

**Inputs:**
- `ResponseObject` (VaRest Response)

**Blueprint Flow:**

```
Event HandlePollResponse
    ↓
[Get] Response Object
    ↓
Get String Field "status"
    ↓
[Branch] status == "completed"
    ├─ TRUE:
    │  ├─ Get String Field "image" (base64 data)
    │  ├─ [Set] GeneratedImageBase64 = image data
    │  ├─ [Set] IsPolling = false
    │  ├─ Call: OnImageReady (GeneratedImageBase64)
    │  └─ Print "Image generated successfully!"
    │
    ├─ FALSE → Branch status == "processing"
    │  ├─ TRUE:
    │  │  ├─ Print "Still processing... (attempt X/60)"
    │  │  ├─ Delay (PollDelay)
    │  │  └─ Call: PollForCompletion (loop)
    │  │
    │  └─ FALSE (ERROR):
    │     ├─ Get String Field "error"
    │     ├─ Print Error Message
    │     ├─ [Set] IsPolling = false
    │     └─ Call: OnImageFailed (error)
```

---

## Step 4: Blueprint - Decode & Display Image

### Event: `OnImageReady`

**Inputs:**
- `ImageBase64` (String)

**Blueprint Flow:**

```
Event OnImageReady
    ↓
[Option A] Save to File
    ├─ Decode Base64 to Byte Array
    │  (Use: Base64 Decode node)
    │  ├─ Input: ImageBase64
    │  └─ Output: ByteArray
    │
    ├─ Save to File
    │  ├─ Filename: "Saved/Screenshots/generated_image.png"
    │  ├─ Data: ByteArray
    │
    └─ Print "Image saved to: Saved/Screenshots/generated_image.png"

[Option B] Create Texture Asset
    ├─ Decode Base64 to Byte Array
    ├─ Create 2D Texture from Raw Data
    │  ├─ RGBA Format
    │  ├─ Async Create
    │
    └─ Use texture in Material or UI

[Option C] Display in UI
    ├─ Create Image widget
    ├─ Use Material that reads PNG from disk
    │  (saved in Option A)
    │
    └─ Update HUD/Canvas with image
```

---

## Step 5: Example: Complete Event Graph Setup

### In Level Blueprint or Actor Blueprint:

```
Event BeginPlay
    ↓
[Create] Reference to BP_ImageGenerator
    ↓
Create Widget (if UI is used)
    ↓
Bind Button Click → Call SubmitImageRequest
```

### Button Click Event:

```
On Click
    ↓
Get ImageGenerator Reference
    ↓
Call SubmitImageRequest
    ├─ Prompt: "a cybernetic owl, neon lighting, detailed"
    ├─ ModelID: "gpt-image-2.5-flare"
    ├─ AspectRatio: "16:9"
    ↓
Print "Generating image..."
```

---

## Step 6: Testing

### 6.1 In Editor

1. Place `BP_ImageGenerator` actor in level
2. Open Level Blueprint
3. On Event Begin Play → Call `SubmitImageRequest`
4. Set Prompt: `"a futuristic spaceship, detailed, cinematic"`
5. Play (PIE)
6. Check **Output Log** for status messages

### 6.2 Expected Output Log

```
[2026-09-22 10:30:15] Image request submitted...
[2026-09-22 10:30:16] Still processing... (attempt 1/60)
[2026-09-22 10:30:18] Still processing... (attempt 2/60)
[2026-09-22 10:30:20] Still processing... (attempt 3/60)
...
[2026-09-22 10:30:50] Image generated successfully!
[2026-09-22 10:30:51] Image saved to: Saved/Screenshots/generated_image.png
```

---

## Advanced Features

### 1. Custom UI Widget

Create a `WBP_ImageGenerator` widget blueprint:

```
┌─────────────────────────────────┐
│  Image Generation UI             │
├─────────────────────────────────┤
│ Prompt Input:  [_______________]│
│ Model Select:  [Flare ▼]        │
│ Aspect Ratio:  [16:9 ▼]         │
│ [Generate] [Cancel]             │
├─────────────────────────────────┤
│                                 │
│   [Generated Image Here]        │
│   (Updates when ready)          │
│                                 │
├─────────────────────────────────┤
│ Status: Processing... (3/60)    │
└─────────────────────────────────┘
```

### 2. Add Model Selector

```
Enum EImageModel
    ├─ Flare (gpt-image-2.5-flare)
    └─ Sunburst (gpt-image-2.5-sunburst)

Enum EAspectRatio
    ├─ Square (1:1)
    ├─ Widescreen (16:9)
    └─ Portrait (9:16)
```

### 3. Error Handling Improvements

```
Add to HandlePollResponse:
    ├─ 402 Status → "Upgrade to Pro plan"
    ├─ 401 Status → "API key invalid"
    ├─ 500 Status → "Server error, retry"
    └─ Timeout → "Generation took too long"
```

### 4. Concurrent Requests

```
Store multiple CurrentImageID values
    ├─ Use Map<ImageID, Metadata>
    └─ Poll multiple jobs simultaneously
```

---

## Troubleshooting Blueprint Issues

| Issue | Solution |
|-------|----------|
| No connection error | Check RelayURL is correct, relay is running |
| 400 Bad Request | Ensure JSON fields match exactly (case-sensitive) |
| Polling never completes | Increase MaxPollAttempts or PollDelay |
| Image appears corrupted | Relay connection may have dropped during download |
| VaRest subsystem not found | Ensure VaRest plugin is enabled in project |

---

## Complete Node Reference

### VaRest Nodes You'll Need

- **Get VaRest Subsystem** → Returns subsystem reference
- **Construct VaRest Request** → Creates HTTP request object
- **Set URL** → Sets endpoint URL
- **Set Verb** → Sets HTTP method (POST, GET)
- **Add Header** → Adds custom headers if needed
- **Execute (Process Request)** → Sends request
- **Get String Field** → Extracts JSON string value
- **Get Integer Field** → Extracts JSON number value

### JSON Nodes

- **Construct JSON Object** → Creates JSON payload
- **Set String Field** → Adds string to JSON
- **Set Integer Field** → Adds number to JSON

### Utility Nodes

- **Base64 Decode** → Decodes image data
- **Delay** → Wait between retries
- **Branch** → If/else logic
- **Do N** → Loop N times

---

## Next Steps

1. ✅ Create `BP_ImageGenerator` actor
2. ✅ Implement `SubmitImageRequest` function
3. ✅ Implement polling loop with `PollForCompletion`
4. ✅ Handle image in `OnImageReady` event
5. ✅ Test with "Output Log" messages
6. ✅ Create UI widget for easier interaction
7. ✅ Add error handling for edge cases

---

## Related Files

- 📄 [README.md](README.md) - Project overview
- 🔧 [image gen openai 2_5 via 11lab  ue relay.js](image%20gen%20openai%202_5%20via%2011lab%20%20ue%20relay.js) - Relay server code
- 🚀 [start image relay ue5.bat](start%20image%20relay%20ue5.bat) - Launch script

---

**Made with ❤️ for UE5**
