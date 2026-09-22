#!/bin/bash

echo "=== Image Reference Generation Test ==="
echo ""

# Configuration
RELAY_URL="http://localhost:3001"
IMAGE_PATH="C:/Users/amir_desktop/Documents/Unreal Projects/__service_apps/__image gen_UE/test/input.jpg"
PROMPT="enhance the colors and add vibrant lighting, improve details"
MODEL="gpt-image-2.5-flare"
ASPECT="16:9"

echo "[1/5] Checking relay health..."

# Check health
HEALTH=$(curl -s http://localhost:3001/health)
if echo "$HEALTH" | grep -q "ok"; then
    echo "✅ Relay is running"
else
    echo "❌ Relay not responding"
    exit 1
fi

echo ""
echo "[2/5] Reading and encoding image..."

# Read image and convert to base64
if [ ! -f "$IMAGE_PATH" ]; then
    echo "❌ Image not found: $IMAGE_PATH"
    exit 1
fi

# Note: Using Windows path, so we need to adjust
WINDOWS_PATH=$(cygpath -w "$IMAGE_PATH" 2>/dev/null || echo "$IMAGE_PATH")

# Convert image to base64
BASE64=$(cat "$WINDOWS_PATH" | base64 -w 0)
IMAGE_SIZE=$(stat -f%z "$IMAGE_PATH" 2>/dev/null || stat -c%s "$IMAGE_PATH" 2>/dev/null)

echo "✅ Image loaded: $(echo "scale=2; $IMAGE_SIZE / 1024" | bc) KB"
echo "   Base64 size: ${#BASE64} characters"

echo ""
echo "[3/5] Submitting to /generate-image-from-reference..."

# Create JSON payload with proper escaping
JSON_PAYLOAD=$(cat <<EOF
{
  "prompt": "$PROMPT",
  "model_id": "$MODEL",
  "aspect_ratio": "$ASPECT",
  "image_data": "data:image/jpeg;base64,$BASE64"
}
EOF
)

# Submit request
RESPONSE=$(curl -s -X POST "$RELAY_URL/generate-image-from-reference" \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD")

IMAGE_ID=$(echo "$RESPONSE" | grep -o '"image_id":"[^"]*' | cut -d'"' -f4)
STATUS=$(echo "$RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)

if [ -z "$IMAGE_ID" ]; then
    echo "❌ Request failed"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "✅ Request accepted"
echo "   Image ID: $IMAGE_ID"
echo "   Status: $STATUS"

echo ""
echo "[4/5] Polling for completion (max 60 attempts)..."

# Poll for completion
MAX_ATTEMPTS=60
POLL_DELAY=2
ATTEMPT=0
COMPLETE=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ] && [ "$COMPLETE" = "false" ]; do
    sleep $POLL_DELAY
    ATTEMPT=$((ATTEMPT + 1))

    POLL_RESPONSE=$(curl -s "$RELAY_URL/image-status?image_id=$IMAGE_ID")
    CURRENT_STATUS=$(echo "$POLL_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)

    if [ "$CURRENT_STATUS" = "completed" ]; then
        echo "✅ Generation complete!"
        IMAGE_DATA=$(echo "$POLL_RESPONSE" | grep -o '"image":"[^"]*' | cut -d'"' -f4)
        IMAGE_SIZE_BYTES=$(echo "$POLL_RESPONSE" | grep -o '"size_bytes":[0-9]*' | cut -d':' -f2)
        echo "   Image size: $IMAGE_SIZE_BYTES bytes"
        COMPLETE=true
    elif [ "$CURRENT_STATUS" = "processing" ]; then
        echo "   ⏳ Attempt $ATTEMPT/$MAX_ATTEMPTS - processing..."
    else
        echo "   ⚠️  Status: $CURRENT_STATUS"
    fi
done

if [ "$COMPLETE" = "false" ]; then
    echo "❌ Generation timeout after $MAX_ATTEMPTS attempts"
    exit 1
fi

echo ""
echo "[5/5] Saving generated image..."

# Decode and save image
OUTPUT_PATH="C:/Users/amir_desktop/Documents/Unreal Projects/__service_apps/__image gen_UE/test/output.jpg"

# Decode base64
echo "$IMAGE_DATA" | base64 -d > "$OUTPUT_PATH" 2>/dev/null || \
echo "$IMAGE_DATA" | base64 -D > "$OUTPUT_PATH" 2>/dev/null

if [ -f "$OUTPUT_PATH" ]; then
    OUTPUT_SIZE=$(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH" 2>/dev/null)
    echo "✅ Image saved: $OUTPUT_PATH"
    echo "   File size: $(echo "scale=2; $OUTPUT_SIZE / 1024" | bc) KB"
else
    echo "❌ Failed to save image"
    exit 1
fi

echo ""
echo "=== Test Complete ==="
echo "✅ Image reference generation working!"
echo ""
echo "Summary:"
echo "  Input image:  $(echo "scale=2; $IMAGE_SIZE / 1024" | bc) KB (JPEG)"
echo "  Prompt:       $PROMPT"
echo "  Model:        $MODEL"
echo "  Aspect ratio: $ASPECT"
echo "  Generation time: $((ATTEMPT * POLL_DELAY)) seconds"
echo "  Output:       $OUTPUT_PATH"
