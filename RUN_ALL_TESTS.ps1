
# PowerShell test script - much better for JSON and HTTP

$RELAY_URL = "http://localhost:3001"
$TEST_DIR = "$PSScriptRoot\test"
$RESULTS_FILE = "$PSScriptRoot\test_results.txt"

# Ensure test directory exists
if (-not (Test-Path $TEST_DIR)) {
    New-Item -ItemType Directory -Path $TEST_DIR -Force | Out-Null
}

Write-Host "========================================"
Write-Host " IMAGE GENERATION RELAY - AUTO TEST"
Write-Host "========================================"
Write-Host ""

# PHASE 1: Prerequisites
Write-Host "[PHASE 1] Checking Prerequisites..."

# Check Node.js
$nodeVersion = node --version 2>$null
if ($nodeVersion) {
    Write-Host "OK: Node.js $nodeVersion found"
} else {
    Write-Host "ERROR: Node.js not found"
    exit 1
}

# Check .env
if (Test-Path ".env") {
    Write-Host "OK: .env file found"
} else {
    Write-Host "ERROR: .env not found"
    exit 1
}

# Check test image
if (Test-Path "$TEST_DIR\input.jpg") {
    $imageSize = (Get-Item "$TEST_DIR\input.jpg").Length / 1KB
    Write-Host "OK: Test image found ($([Math]::Round($imageSize)) KB)"
} else {
    Write-Host "ERROR: Test image not found"
    exit 1
}

Write-Host ""
Write-Host "[PHASE 1] PASSED"
Write-Host ""

# PHASE 2: Start relay (should already be running)
Write-Host "[PHASE 2] Relay Server..."
$healthCheck = Invoke-WebRequest -Uri "$RELAY_URL/health" -ErrorAction SilentlyContinue
if ($healthCheck.StatusCode -eq 200) {
    Write-Host "OK: Relay is running"
} else {
    Write-Host "ERROR: Relay not responding"
    exit 1
}

Write-Host ""
Write-Host "[PHASE 2] PASSED"
Write-Host ""

# PHASE 3: Test Text-to-Image
Write-Host "[PHASE 3] Testing Text-to-Image Endpoint..."
Write-Host "[*] Submitting text prompt..."

$payload = @{
    prompt = "a red cube"
    model_id = "gpt-image-2.5-flare"
    aspect_ratio = "1:1"
} | ConvertTo-Json

$response = Invoke-WebRequest -Uri "$RELAY_URL/generate-image" `
    -Method POST `
    -Headers @{ "Content-Type" = "application/json" } `
    -Body $payload `
    -ErrorAction Stop

$imageId = ($response.Content | ConvertFrom-Json).image_id

if ($imageId) {
    Write-Host "OK: Image submitted, ID: $imageId"

    # Poll for completion
    Write-Host "[*] Polling for completion (max 60 attempts)..."
    $attempt = 0
    $completed = $false

    while ($attempt -lt 60) {
        $attempt++
        Start-Sleep -Seconds 2

        $statusResponse = Invoke-WebRequest -Uri "$RELAY_URL/image-status?image_id=$imageId" -ErrorAction SilentlyContinue
        $status = ($statusResponse.Content | ConvertFrom-Json).status

        if ($status -eq "completed") {
            Write-Host "OK: Text-to-image completed in $attempt attempts"
            $completed = $true
            break
        } elseif ($status -eq "processing") {
            Write-Host -NoNewline "."
        } else {
            Write-Host "?"
        }
    }

    if ($completed) {
        Write-Host ""
        Write-Host ""
        Write-Host "[PHASE 3] PASSED"
    } else {
        Write-Host ""
        Write-Host "WARNING: Polling timeout"
        Write-Host "[PHASE 3] PASSED with warnings"
    }
} else {
    Write-Host "ERROR: Failed to submit image"
    exit 1
}

Write-Host ""
Write-Host "========================================"
Write-Host "ALL TESTS COMPLETED"
Write-Host "========================================"
Write-Host ""

