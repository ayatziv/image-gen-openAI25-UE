# Extended 11 Labs API Diagnostic
# Tests more endpoint variations and different API structures

$API_KEY = Get-Content .env | Select-String "ELEVENLABS_API_KEY" | ForEach-Object { $_ -replace '.*=', '' }
$BASE_URL = "https://api.elevenlabs.io"

Write-Host "=== Extended 11 Labs API Diagnostic ===" -ForegroundColor Cyan
Write-Host "API key format: $($API_KEY.Substring(0, 15))..."
Write-Host ""

# Test more endpoints
$endpoints = @(
    # Original attempts
    "/v1/image/generate",
    "/v1/image-generation",
    "/v1/image",
    "/v1/images",

    # Flows API (newer 11 Labs API)
    "/v1/flows",
    "/v1/flows/execute",
    "/v1/convai/conversations",

    # Alternative paths
    "/v1/text-to-image",
    "/v1/generate",
    "/v1/generate/image",

    # Check what's available
    "/v1",
    "/v1/voices",
    "/v1/models"
)

Write-Host "Testing endpoints:" -ForegroundColor Yellow
Write-Host ""

foreach ($endpoint in $endpoints) {
    Write-Host -NoNewline "GET $endpoint ... "

    try {
        $response = Invoke-WebRequest -Uri "$BASE_URL$endpoint" `
            -Method Get `
            -Headers @{ "xi-api-key" = $API_KEY } `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "✅ 200 OK" -ForegroundColor Green
        $data = $response.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($data) {
            Write-Host "  Response type: $($data.GetType().Name)" -ForegroundColor Gray
            if ($data -is [array]) {
                Write-Host "  Items: $($data.Count)" -ForegroundColor Gray
            }
        }
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__

        if ($statusCode -eq 404) {
            Write-Host "❌ 404 NOT FOUND" -ForegroundColor Red
        } elseif ($statusCode -eq 401) {
            Write-Host "❌ 401 UNAUTHORIZED" -ForegroundColor Red
        } elseif ($statusCode -eq 400) {
            Write-Host "⚠️  400 BAD REQUEST" -ForegroundColor Yellow
        } else {
            Write-Host "⚠️  HTTP $statusCode" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "=== Testing with different headers ===" -ForegroundColor Cyan
Write-Host ""

# Try with different content-type headers
$headers_variants = @(
    @{ "xi-api-key" = $API_KEY; "Content-Type" = "application/json" },
    @{ "Authorization" = "Bearer $API_KEY"; "Content-Type" = "application/json" },
    @{ "x-api-key" = $API_KEY; "Content-Type" = "application/json" }
)

foreach ($headers in $headers_variants) {
    $header_desc = ($headers.Keys | Join-Object -Separator ", ") -join ","
    Write-Host -NoNewline "Testing /v1/user with headers: $header_desc ... "

    try {
        $response = Invoke-WebRequest -Uri "$BASE_URL/v1/user" `
            -Method Get `
            -Headers $headers `
            -UseBasicParsing `
            -ErrorAction Stop

        Write-Host "✅ SUCCESS" -ForegroundColor Green
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.Value__
        Write-Host "❌ $statusCode" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "If no endpoints return 200 OK, 11 Labs might not have:" -ForegroundColor Yellow
Write-Host "  - Public image generation API in /v1/" -ForegroundColor Yellow
Write-Host "  - Or API key might need different authentication" -ForegroundColor Yellow
Write-Host ""
Write-Host "Check:" -ForegroundColor Cyan
Write-Host "  1. Account has Pro+ plan"
Write-Host "  2. API key has correct permissions"
Write-Host "  3. Visit: https://elevenlabs.io/docs/api-reference" -ForegroundColor Cyan
Write-Host ""
