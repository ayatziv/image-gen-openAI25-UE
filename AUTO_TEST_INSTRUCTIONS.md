# Automatic Test - Complete Guide

Run all tests automatically with one command.

---

## What Gets Tested

✅ **Phase 1: Prerequisites**
- Node.js installation
- .env configuration
- Test image file

✅ **Phase 2: Relay Server**
- Start relay on port 3001
- Health check endpoint

✅ **Phase 3: Text-to-Image**
- Submit text prompt
- Poll for completion
- Verify response

✅ **Phase 4: Image Reference**
- Read input.jpg
- Encode to base64
- Submit with prompt
- Poll for completion
- Verify response

---

## Quick Start

### 1. Open Command Prompt

Navigate to your local folder:

```bash
cd "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE"
```

### 2. Run the Test

```bash
RUN_ALL_TESTS.bat
```

That's it! The script will:
- ✅ Check everything is installed
- ✅ Start the relay automatically
- ✅ Run all tests
- ✅ Display results
- ✅ Save report to `test_results.txt`

---

## What Happens

```
[PHASE 1] Checking Prerequisites...
  ✓ Node.js found
  ✓ .env file found
  ✓ Test image found

[PHASE 2] Starting Relay Server...
  ✓ Relay started on http://localhost:3001
  ✓ Health check passed

[PHASE 3] Testing Text-to-Image Endpoint...
  ✓ Image submitted (ID: img_abc123)
  ✓ Polling... Attempt 1/60
  ✓ Polling... Attempt 2/60
  ✓ Polling... Attempt 8/60 - COMPLETED

[PHASE 4] Testing Image Reference Endpoint...
  ✓ Image loaded (884 KB)
  ✓ Base64 encoded (1206300 chars)
  ✓ Reference submitted (ID: img_xyz789)
  ✓ Polling... Attempt 1/60
  ✓ Polling... Attempt 12/60 - COMPLETED

========================================
ALL TESTS COMPLETED SUCCESSFULLY
========================================
```

---

## Expected Timing

| Phase | Time |
|-------|------|
| Phase 1 (Prerequisites) | < 5 seconds |
| Phase 2 (Relay startup) | 5-10 seconds |
| Phase 3 (Text-to-Image) | 20-40 seconds |
| Phase 4 (Image Reference) | 20-40 seconds |
| **Total** | **~1 minute** |

---

## Test Results

After the test completes, check:

### Results File
```
test_results.txt
```

This contains:
- Test start time
- Phase status (PASS/FAIL)
- Completion time
- Summary

### View Results
```bash
type test_results.txt
```

---

## What Each Phase Tests

### Phase 1: Prerequisites ✅
```
✓ Node.js installed (v16+)
✓ .env file exists with ELEVENLABS_API_KEY
✓ input.jpg exists in test\ folder
```

### Phase 2: Relay Server ✅
```
✓ Relay starts successfully
✓ Port 3001 is available
✓ /health endpoint responds
✓ Server is ready for requests
```

### Phase 3: Text-to-Image ✅
```
✓ /generate-image endpoint works
✓ Accepts JSON with prompt
✓ Returns valid image_id
✓ Status polling works
✓ Generation completes within timeout
```

### Phase 4: Image Reference ✅
```
✓ input.jpg loads successfully
✓ Converts to base64 correctly
✓ /generate-image-from-reference accepts request
✓ Returns valid image_id
✓ Status polling works
✓ Generation completes within timeout
```

---

## Success Criteria

✅ **All phases show PASSED**

```
[PHASE 1] PASSED
[PHASE 2] PASSED
[PHASE 3] PASSED
[PHASE 4] PASSED

ALL TESTS COMPLETED SUCCESSFULLY
```

---

## Troubleshooting

### "Node.js not found"
```
Install from: https://nodejs.org/
Then restart Command Prompt
```

### ".env file not found"
```
Copy .env.example to .env
Add your ELEVENLABS_API_KEY
```

### "Test image not found"
```
Make sure test\input.jpg exists
File should be 884 KB JPEG
```

### "Could not connect to relay"
```
Check if port 3001 is available
Close other apps using port 3001
Run with administrator privileges
```

### "Phase 3 timeout"
```
Generation takes 15-30 seconds
Script waits up to 60 attempts (120 seconds)
If timing out, 11 Labs API might be slow
Try again in a few minutes
```

### "Phase 4 fails to encode"
```
PowerShell might need execution policy change
Run:
  powershell -ExecutionPolicy Bypass -File test_image_reference.ps1
```

---

## Stopping the Test

If the test gets stuck:

```bash
# Press Ctrl+C to stop
# Relay window will close automatically
```

---

## Next Steps

Once all tests pass:

1. ✅ Relay works locally
2. ✅ Text-to-image working
3. ✅ Image reference working
4. 👉 Build UE5 blueprints (see BLUEPRINT_IMAGE_REFERENCE.md)
5. 👉 Test blueprints in editor
6. 👉 Integrate into your game

---

## Files Used

```
RUN_ALL_TESTS.bat          - Main test script
test\input.jpg             - Test image (884 KB)
test\input_base64.txt      - Generated during test
test\payload.json          - Generated during test
test_results.txt           - Test report (generated)
```

---

## Advanced: Run Without Batch File

If you prefer manual testing:

```bash
# Terminal 1: Start relay
node "image gen openai 2_5 via 11lab  ue relay.js"

# Terminal 2: Test
QUICK_TEST_WITH_IMAGE.md
```

Or use the automated scripts:

```bash
# PowerShell
powershell -ExecutionPolicy Bypass -File test_image_reference.ps1

# Bash
bash test_image_reference.sh
```

---

## Getting Help

Check these files for more details:

- `TESTING_IMAGE_REFERENCE.md` - Detailed phase-by-phase testing
- `QUICK_TEST_WITH_IMAGE.md` - Manual step-by-step guide
- `BLUEPRINT_IMAGE_REFERENCE.md` - UE5 blueprint implementation
- `README.md` - Project overview

---

**Ready? Run it now!**

```bash
RUN_ALL_TESTS.bat
```

🚀

