@echo off
REM Test different curl request formats for 11 Labs Flows API

setlocal enabledelayedexpansion

for /f "tokens=2 delims==" %%A in ('findstr "ELEVENLABS_API_KEY" .env') do set API_KEY=%%A

if "!API_KEY!"=="" (
    echo ERROR: API_KEY not found in .env
    pause
    exit /b 1
)

echo.
echo ========================================
echo  11 Labs Flows API - cURL Test
echo ========================================
echo.
echo API Key: !API_KEY:~0,15!...
echo.

REM Test 1: POST with text parameter
echo [Test 1] POST /v1/flows/image/create with text parameter
echo.
curl -X POST https://api.elevenlabs.io/v1/flows/image/create ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"a red cube\"}"
echo.
echo.

REM Test 2: POST with prompt parameter
echo [Test 2] POST /v1/flows/image/create with prompt parameter
echo.
curl -X POST https://api.elevenlabs.io/v1/flows/image/create ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json" ^
  -d "{\"prompt\":\"a red cube\"}"
echo.
echo.

REM Test 3: POST with full parameters
echo [Test 3] POST /v1/flows/image/create with all parameters
echo.
curl -X POST https://api.elevenlabs.io/v1/flows/image/create ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"a red cube\",\"model\":\"gpt-image-2.5-flare\",\"aspect_ratio\":\"1:1\"}"
echo.
echo.

REM Test 4: GET request
echo [Test 4] GET /v1/flows/image/create
echo.
curl -X GET https://api.elevenlabs.io/v1/flows/image/create ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json"
echo.
echo.

REM Test 5: Try different endpoint path
echo [Test 5] POST /v1/flows/image (without /create)
echo.
curl -X POST https://api.elevenlabs.io/v1/flows/image ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json" ^
  -d "{\"text\":\"a red cube\"}"
echo.
echo.

REM Test 6: Check available endpoints
echo [Test 6] GET /v1/flows (list available flows)
echo.
curl -X GET https://api.elevenlabs.io/v1/flows ^
  -H "xi-api-key: !API_KEY!" ^
  -H "Content-Type: application/json"
echo.
echo.

echo ========================================
echo Review the responses above to find which works!
echo ========================================
echo.
pause
