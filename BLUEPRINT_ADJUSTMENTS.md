# Blueprint Adjustments: Music → Image Generation

Convert the music generation blueprint to work with our image generation relay.

---

## 1. URL Endpoints

### ❌ Music (Old)
```
POST http://localhost:3000/generate-music
GET  http://localhost:3000/music-status?music_id=...
GET  http://localhost:3000/health
```

### ✅ Image (New)
```
POST http://localhost:3001/generate-image
GET  http://localhost:3001/image-status?image_id=...
GET  http://localhost:3001/health
```

**Changes:**
- Port: `3000` → `3001`
- Endpoint: `generate-music` → `generate-image`
- Status endpoint: `music-status` → `image-status`
- Query param: `music_id` → `image_id`

---

## 2. JSON Request Fields

### ❌ Music (Old)
```json
{
  "prompt": "cabaret style",
  "music_length_ms": 60000,
  "model_id": "music_v2",
  "finetune_id": "gyxiulmcqokirelkks9m"
}
```

### ✅ Image (New)
```json
{
  "prompt": "a cybernetic owl, neon lighting",
  "model_id": "gpt-image-2.5-flare",
  "aspect_ratio": "16:9"
}
```

**Changes in Blueprint:**
| Node | Music | Image |
|------|-------|-------|
| Set String Field 1 | `prompt` | `prompt` ✅ (same) |
| Set Number Field | `music_length_ms` | ❌ **Remove** |
| Set String Field 2 | `model_id` = `music_v2` | `model_id` = `gpt-image-2.5-flare` |
| Set String Field 3 | `finetune_id` | ❌ **Remove** |
| Set String Field 4 | (new) | `aspect_ratio` = `16:9` |

**Blueprint Action:**
```
1. Keep: Prompt field
2. Change: model_id value from "music_v2" → "gpt-image-2.5-flare"
3. Delete: music_length_ms node
4. Delete: finetune_id node
5. Add: aspect_ratio field with value "16:9"
```

---

## 3. Response Field Names

### ❌ Music (Old)
```
Get String Field "audio"  ← Contains base64 audio data
```

### ✅ Image (New)
```
Get String Field "image"  ← Contains base64 image data
```

**Blueprint Change:**
```
Find: Get String Field node with Field Name = "audio"
Change to: Field Name = "image"
```

---

## 4. File Saving

### ❌ Music (Old)
```
Save Array To File
  └─ Filename: "Saved/Screenshots/generated_music.mp3"
```

### ✅ Image (New)
```
Save Array To File
  └─ Filename: "Saved/Screenshots/generated_image.png"
```

**Blueprint Change:**
```
Find: Save Array To File node
Change: Filename from "...generated_music.mp3" → "...generated_image.png"
```

---

## 5. Status Polling Field

### ❌ Music (Old)
In `HandlePollResponse` event:
```
Branch: if status == "completed"
  └─ Get String Field "audio"
```

### ✅ Image (New)
In `HandlePollResponse` event:
```
Branch: if status == "completed"
  └─ Get String Field "image"
```

**Blueprint Change:**
- The status check logic stays the same
- Only change the field being extracted: `"audio"` → `"image"`

---

## 6. UI Labels & Print Strings

### ❌ Music (Old)
```
Print String: "music gen finished"
Print String: "music file created"
Set Text: "Music gen server status"
Set Text: "music_v2"
```

### ✅ Image (New)
```
Print String: "image gen finished"
Print String: "image file created"
Set Text: "Image gen server status"
Set Text: "gpt-image-2.5-flare"
```

**Blueprint Change:**
```
Find all Print String nodes
Replace: "music" → "image"

Find all Set Text nodes
Replace: "music" → "image"
Replace: "music_v2" → "gpt-image-2.5-flare"
```

---

## 7. Variables Rename (Optional but Cleaner)

### ❌ Old Variable Names
```
- music_generation_send
- check_music_gen_relay_health
- music_gen_server_status
- Singgen (?)
```

### ✅ New Variable Names
```
- image_generation_send
- check_image_gen_relay_health
- image_gen_server_status
- ImageGenUI
```

---

## Complete Checklist

- [ ] **URLs**: Change `3000` → `3001`, `generate-music` → `generate-image`
- [ ] **JSON Fields**: Keep `prompt`, change `model_id`, remove `music_length_ms`, remove `finetune_id`, add `aspect_ratio`
- [ ] **Response Field**: Change `"audio"` → `"image"`
- [ ] **File Path**: Change `.mp3` → `.png`
- [ ] **Status Field**: Still `"completed"`, `"processing"` (no change needed)
- [ ] **UI Labels**: Replace "music" → "image" in all Print Strings
- [ ] **Timer/Polling**: Keep same (60s for health check, 2-3s polling)
- [ ] **Base64 Decode**: No change needed (works for both audio & image)

---

## Quick Side-by-Side: Key Nodes to Change

### Node 1: Set URL (POST request)
```
OLD: http://localhost:3000/generate-music
NEW: http://localhost:3001/generate-image
```

### Node 2: Set String Field (model_id)
```
OLD: model_id = "music_v2"
NEW: model_id = "gpt-image-2.5-flare"
```

### Node 3: Add New String Field
```
NEW: Add this node!
  Field Name: "aspect_ratio"
  String Value: "16:9"
```

### Node 4: Remove These Nodes
```
DELETE: Set Number Field (music_length_ms)
DELETE: Set String Field (finetune_id)
```

### Node 5: Get String Field (response)
```
OLD: Field Name = "audio"
NEW: Field Name = "image"
```

### Node 6: Save Array To File
```
OLD: "Saved/Screenshots/generated_music.mp3"
NEW: "Saved/Screenshots/generated_image.png"
```

### Node 7: Set URL (GET status)
```
OLD: http://localhost:3000/music-status?music_id=...
NEW: http://localhost:3001/image-status?image_id=...
```

---

## Port Note

⚠️ **IMPORTANT:** The relay runs on **port 3001**, not 3000!

Make sure in your batch file (`start image relay ue5.bat`):
```
node "image gen openai 2_5 via 11lab  ue relay.js"
```

Check `.env` file has:
```
IMAGE_PORT=3001
```

---

## Testing After Changes

1. Make all adjustments above
2. Save blueprint
3. Ensure relay is running: `start image relay ue5.bat`
4. In editor, play (PIE)
5. Check Output Log for:
   ```
   [ImageGen] Image request submitted...
   [ImageGen] Still processing... (attempt 1/60)
   [ImageGen] image file created
   ```

---

## Summary Table

| Component | Music | Image | Change |
|-----------|-------|-------|--------|
| Server Port | 3000 | 3001 | ✏️ Change |
| Generate Endpoint | `/generate-music` | `/generate-image` | ✏️ Change |
| Status Endpoint | `/music-status` | `/image-status` | ✏️ Change |
| ID Field | `music_id` | `image_id` | ✏️ Change |
| Prompt | `prompt` | `prompt` | ✅ Keep |
| Model Field | `music_v2` | `gpt-image-2.5-flare` | ✏️ Change |
| Duration Field | `music_length_ms` | N/A | ❌ Remove |
| Finetune Field | `finetune_id` | N/A | ❌ Remove |
| Aspect Ratio | N/A | `aspect_ratio` | ➕ Add |
| Response Field | `audio` | `image` | ✏️ Change |
| File Extension | `.mp3` | `.png` | ✏️ Change |
| Status Values | `completed`, `processing` | `completed`, `processing` | ✅ Keep |

---

**That's it!** Make these changes and your blueprint will work with the image generation relay! 🎨
