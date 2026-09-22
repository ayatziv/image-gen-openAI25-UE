# 11 Labs API Diagnostic Tool
# Tests different endpoint variations to find the correct one

$API_KEY = Get-Content .env | Select-String "ELEVENLABS_API_KEY" | ForEach-Object { $_ -replace '.*=', '' }
$BASE_URL = "https://api.elevenlabs.io"

Write-Host "=== 11 Labs API Diagnostic ===" -ForegroundColor Cyan
Write-Host "Base URL: $BASE_URL"
Write-Host "Testing with API key: $($API_KEY.Substring(0, 10))..."
Write-Host ""

# Test endpoints
$endpoints = @(
    "/v1/image/generate",
    "/v1/image-generation",
    "/v1/image",
    "/v1/images",
    "/v1/images/generate",
    "/v1/generate-image",
    "/v1/image/create",
    "/v1/image-create",
    "/v1/text-to-image"
)

$payload = @{
    prompt = "test"
    model_id = "gpt-image-2.5-flare"
    aspect_ratio = "1:1"
} | ConvertTo-Json

Write-Host "Testing POST endpoints:" -ForegroundColor Yellow
Write-Host ""

foreach ($endpoint in $endpoints) {
    Write-Host -NoNewline "Testing: $endpoint ... "

    try {
        $response = Invoke-WebRequest -Uri "$BASE_URL$endpoint" `
            -Method Post `
            -Headers @{ "xi-api-key" = $API_KEY; "Content-Type" = "application/json" } `
            -Body $payload `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "✅ SUCCESS (200)" -ForegroundColor Green
        Write-Host "Response: $($response.Content | ConvertFrom-Json | ConvertTo-Json -Depth 2)" -ForegroundColor Green
        Write-Host ""
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__

        if ($statusCode -eq 404) {
            Write-Host "❌ NOT FOUND (404)" -ForegroundColor Red
        } elseif ($statusCode -eq 401) {
            Write-Host "❌ UNAUTHORIZED (401) - Check API key" -ForegroundColor Red
        } elseif ($statusCode -eq 403) {
            Write-Host "❌ FORBIDDEN (403) - Check permissions" -ForegroundColor Red
        } else {
            Write-Host "⚠️  HTTP $statusCode" -ForegroundColor Yellow
            try {
                $errorBody = $_.Exception.Response.Content.ReadAsStream()
                $reader = New-Object System.IO.StreamReader($errorBody)
                Write-Host "Response: $($reader.ReadToEnd())" -ForegroundColor Yellow
            } catch {}
        }
    }
}

Write-Host ""
Write-Host "=== Testing Account/Workspace Info ===" -ForegroundColor Cyan
Write-Host ""

Write-Host -NoNewline "Testing: /v1/user ... "
try {
    $response = Invoke-WebRequest -Uri "$BASE_URL/v1/user" `
        -Method Get `
        -Headers @{ "xi-api-key" = $API_KEY } `
        -UseBasicParsing `
        -ErrorAction Stop

    Write-Host "✅ SUCCESS" -ForegroundColor Green
    $data = $response.Content | ConvertFrom-Json
    Write-Host "Subscription: $($data.subscription_tier)" -ForegroundColor Green
    Write-Host "Full response:" -ForegroundColor Gray
    Write-Host ($data | ConvertTo-Json) -ForegroundColor Gray
} catch {
    Write-Host "❌ FAILED ($($_.Exception.Response.StatusCode.Value__))" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Diagnosis Complete ===" -ForegroundColor Cyan
