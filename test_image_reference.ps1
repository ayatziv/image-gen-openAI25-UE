# Test Image Reference Generation
# This script tests the image reference endpoint with input.jpg

Write-Host "=== Image Reference Generation Test ===" -ForegroundColor Cyan
Write-Host ""

# Configuration
$RELAY_URL = "http://localhost:3001"
$IMAGE_PATH = "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test\input.jpg"
$PROMPT = "enhance the colors and add vibrant lighting"
$MODEL = "gpt-image-2.5-flare"
$ASPECT = "16:9"

Write-Host "[1/5] Checking relay health..." -ForegroundColor Yellow

# Check health
$healthResponse = Invoke-WebRequest -Uri "$RELAY_URL/health" -Method Get
if ($healthResponse.StatusCode -eq 200) {
    Write-Host "✅ Relay is running" -ForegroundColor Green
} else {
    Write-Host "❌ Relay not responding" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "[2/5] Reading and encoding image..." -ForegroundColor Yellow

# Read image and convert to base64
if (-not (Test-Path $IMAGE_PATH)) {
    Write-Host "❌ Image not found: $IMAGE_PATH" -ForegroundColor Red
    exit
}

$imageBytes = [System.IO.File]::ReadAllBytes($IMAGE_PATH)
$base64String = [System.Convert]::ToBase64String($imageBytes)
$imageSizeKB = [math]::Round($imageBytes.Length / 1024, 2)

Write-Host "✅ Image loaded: $imageSizeKB KB" -ForegroundColor Green
Write-Host "   Base64 size: $($base64String.Length) characters" -ForegroundColor Gray

Write-Host ""
Write-Host "[3/5] Submitting to /generate-image-from-reference..." -ForegroundColor Yellow

# Create JSON payload
$payload = @{
    prompt = $PROMPT
    model_id = $MODEL
    aspect_ratio = $ASPECT
    image_data = "data:image/jpeg;base64,$base64String"
} | ConvertTo-Json

# Submit request
try {
    $response = Invoke-WebRequest -Uri "$RELAY_URL/generate-image-from-reference" `
        -Method Post `
        -ContentType "application/json" `
        -Body $payload

    $responseData = $response.Content | ConvertFrom-Json
    $imageId = $responseData.image_id
    $status = $responseData.status

    Write-Host "✅ Request accepted" -ForegroundColor Green
    Write-Host "   Image ID: $imageId" -ForegroundColor Gray
    Write-Host "   Status: $status" -ForegroundColor Gray
} catch {
    Write-Host "❌ Request failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "[4/5] Polling for completion (max 60 attempts)..." -ForegroundColor Yellow

# Poll for completion
$maxAttempts = 60
$pollDelay = 2
$attempt = 0
$isComplete = $false

while ($attempt -lt $maxAttempts -and -not $isComplete) {
    Start-Sleep -Seconds $pollDelay
    $attempt++

    try {
        $statusResponse = Invoke-WebRequest -Uri "$RELAY_URL/image-status?image_id=$imageId" -Method Get
        $statusData = $statusResponse.Content | ConvertFrom-Json
        $currentStatus = $statusData.status

        if ($currentStatus -eq "completed") {
            Write-Host "✅ Generation complete!" -ForegroundColor Green
            $imageData = $statusData.image
            $imageSizeBytes = $statusData.size_bytes
            Write-Host "   Image size: $imageSizeBytes bytes" -ForegroundColor Gray
            $isComplete = $true
        } elseif ($currentStatus -eq "processing") {
            Write-Host "   ⏳ Attempt $attempt/$maxAttempts - processing..." -ForegroundColor Gray
        } else {
            Write-Host "   ⚠️  Status: $currentStatus" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   ⚠️  Poll attempt $attempt failed" -ForegroundColor Yellow
    }
}

if (-not $isComplete) {
    Write-Host "❌ Generation timeout after $maxAttempts attempts" -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "[5/5] Saving generated image..." -ForegroundColor Yellow

# Decode and save image
$outputPath = "C:\Users\amir_desktop\Documents\Unreal Projects\__service_apps\__image gen_UE\test\output.jpg"

try {
    $imageBytes = [System.Convert]::FromBase64String($imageData)
    [System.IO.File]::WriteAllBytes($outputPath, $imageBytes)
    Write-Host "✅ Image saved: $outputPath" -ForegroundColor Green
    Write-Host "   File size: $([math]::Round((Get-Item $outputPath).Length / 1024, 2)) KB" -ForegroundColor Gray
} catch {
    Write-Host "❌ Failed to save image" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

Write-Host ""
Write-Host "=== Test Complete ===" -ForegroundColor Cyan
Write-Host "✅ Image reference generation working!" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Input image:  $imageSizeKB KB (JPEG)" -ForegroundColor Gray
Write-Host "  Prompt:       $PROMPT" -ForegroundColor Gray
Write-Host "  Model:        $MODEL" -ForegroundColor Gray
Write-Host "  Aspect ratio: $ASPECT" -ForegroundColor Gray
Write-Host "  Generation time: $($attempt * $pollDelay) seconds" -ForegroundColor Gray
Write-Host "  Output: $outputPath" -ForegroundColor Gray
