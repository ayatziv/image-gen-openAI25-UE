#!/bin/bash

# 11 Labs API Diagnostic Tool
# Tests different endpoint variations to find the correct one

API_KEY="$1"
BASE_URL="https://api.elevenlabs.io"

if [ -z "$API_KEY" ]; then
    echo "Usage: diagnose_api.sh <API_KEY>"
    exit 1
fi

echo "=== 11 Labs API Diagnostic ==="
echo "Base URL: $BASE_URL"
echo "Testing with API key: ${API_KEY:0:10}..."
echo ""

# Test endpoints
ENDPOINTS=(
    "/v1/image/generate"
    "/v1/image-generation"
    "/v1/image"
    "/v1/images"
    "/v1/images/generate"
    "/v1/generate-image"
    "/v1/image/create"
    "/v1/image-create"
    "/v1/text-to-image"
)

PAYLOAD='{"prompt":"test","model_id":"gpt-image-2.5-flare","aspect_ratio":"1:1"}'

echo "Testing POST endpoints:"
echo ""

for endpoint in "${ENDPOINTS[@]}"; do
    echo -n "Testing: $endpoint ... "
    RESPONSE=$(curl -s -X POST "$BASE_URL$endpoint" \
        -H "xi-api-key: $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD" \
        -w "\n%{http_code}")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | head -n-1)

    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        echo "✅ SUCCESS ($HTTP_CODE)"
        echo "Response: $BODY"
        echo ""
    elif [ "$HTTP_CODE" = "404" ]; then
        echo "❌ NOT FOUND (404)"
    elif [ "$HTTP_CODE" = "401" ]; then
        echo "❌ UNAUTHORIZED (401) - Check API key"
    elif [ "$HTTP_CODE" = "403" ]; then
        echo "❌ FORBIDDEN (403) - Check permissions"
    else
        echo "⚠️  HTTP $HTTP_CODE"
        echo "Response: $BODY"
    fi
done

echo ""
echo "=== Testing Account/Workspace Info ==="
echo ""

echo -n "Testing: /v1/user ... "
RESPONSE=$(curl -s -X GET "$BASE_URL/v1/user" \
    -H "xi-api-key: $API_KEY" \
    -w "\n%{http_code}")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS"
    echo "$BODY" | grep -o '"subscription_tier":"[^"]*' || echo "$BODY"
else
    echo "❌ FAILED ($HTTP_CODE)"
fi

echo ""
echo "=== Checking Available Models ==="
echo ""

echo -n "Testing: /v1/models ... "
RESPONSE=$(curl -s -X GET "$BASE_URL/v1/models" \
    -H "xi-api-key: $API_KEY" \
    -w "\n%{http_code}")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ SUCCESS"
else
    echo "❌ FAILED ($HTTP_CODE)"
fi

echo ""
echo "=== Diagnosis Complete ==="
