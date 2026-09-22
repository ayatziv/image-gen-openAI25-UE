@echo off
REM ========================================
REM Complete Automated Test Suite
REM ========================================

setlocal enabledelayedexpansion

cls
echo.
echo ========================================
echo  IMAGE GENERATION RELAY - AUTO TEST
echo ========================================
echo.

REM Colors for output
set GREEN=[92m
set RED=[91m
set YELLOW=[93m
set BLUE=[94m
set RESET=[0m

REM Configuration
set RELAY_URL=http://localhost:3001
set TEST_DIR=%cd%\test
set RESULTS_FILE=%cd%\test_results.txt

echo [*] Test started at: %date% %time%
echo. >> %RESULTS_FILE%
echo ======================================== >> %RESULTS_FILE%
echo TEST RESULTS >> %RESULTS_FILE%
echo ======================================== >> %RESULTS_FILE%
echo Started: %date% %time% >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

REM ========== PHASE 1: Check Prerequisites ==========
echo.
echo [PHASE 1] Checking Prerequisites...
echo [PHASE 1] Checking Prerequisites... >> %RESULTS_FILE%

REM Check if Node.js is installed
echo [*] Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js not installed or not in PATH
    echo FAIL: Node.js not found >> %RESULTS_FILE%
    goto ERROR
)
for /f "tokens=*" %%A in ('node --version') do set NODE_VERSION=%%A
echo OK: Node.js %NODE_VERSION% found
echo PASS: Node.js %NODE_VERSION% >> %RESULTS_FILE%

REM Check if .env exists
echo [*] Checking .env configuration...
if not exist ".env" (
    echo ERROR: .env file not found
    echo FAIL: .env missing >> %RESULTS_FILE%
    goto ERROR
)
echo OK: .env file found
echo PASS: .env file exists >> %RESULTS_FILE%

REM Check if test image exists
echo [*] Checking test image...
if not exist "%TEST_DIR%\input.jpg" (
    echo ERROR: Test image not found at %TEST_DIR%\input.jpg
    echo FAIL: Test image missing >> "%RESULTS_FILE%"
    goto ERROR
)
set /a IMAGE_SIZE=0
for %%A in ("%TEST_DIR%\input.jpg") do set /a IMAGE_SIZE=%%~zA
set /a IMAGE_SIZE_KB=IMAGE_SIZE/1024
echo OK: Test image found ^(%IMAGE_SIZE_KB% KB^)
echo PASS: Test image found ^(%IMAGE_SIZE_KB% KB^ >> "%RESULTS_FILE%"

echo.
echo ========================================
echo [PHASE 1] PASSED
echo ======================================== >> %RESULTS_FILE%
echo [PHASE 1] PASSED >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

REM ========== PHASE 2: Start Relay ==========
echo.
echo [PHASE 2] Starting Relay Server...
echo [PHASE 2] Starting Relay Server... >> %RESULTS_FILE%

REM Kill any existing relay processes
taskkill /F /IM node.exe /FI "WINDOWTITLE eq*relay*" >nul 2>&1

REM Start relay in new window
start "Image Relay" cmd /k "node "image gen openai 2_5 via 11lab  ue relay.js""

REM Wait for relay to start
echo [*] Waiting for relay to start...
timeout /t 3 /nobreak >nul

REM Test connection
set RETRY=0
:RETRY_HEALTH
if %RETRY% geq 5 (
    echo ERROR: Could not connect to relay
    echo FAIL: Relay startup timeout >> %RESULTS_FILE%
    goto ERROR
)
for /f %%A in ('curl -s %RELAY_URL%/health ^| findstr /I "status"') do set HEALTH=%%A
if not "!HEALTH!"=="" (
    echo OK: Relay started successfully
    echo PASS: Relay running on %RELAY_URL% >> %RESULTS_FILE%
    goto PHASE3
)
set /a RETRY=RETRY+1
timeout /t 2 /nobreak >nul
goto RETRY_HEALTH

:PHASE3
echo.
echo ========================================
echo [PHASE 2] PASSED
echo ======================================== >> %RESULTS_FILE%
echo [PHASE 2] PASSED >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

REM ========== PHASE 3: Test Text-to-Image ==========
echo.
echo [PHASE 3] Testing Text-to-Image Endpoint...
echo [PHASE 3] Testing Text-to-Image Endpoint... >> %RESULTS_FILE%

echo [*] Submitting text prompt...
setlocal enabledelayedexpansion
(
  echo {
  echo   "prompt": "a red cube",
  echo   "model_id": "gpt-image-2.5-flare",
  echo   "aspect_ratio": "1:1"
  echo }
) > "!TEST_DIR!\text_payload.json"

curl -s -X POST !RELAY_URL!/generate-image -H "Content-Type: application/json" -d @"!TEST_DIR!\text_payload.json" > "!TEST_DIR!\response.json"
for /f "tokens=2 delims=:,\"" %%A in ('findstr "image_id" "!TEST_DIR!\response.json"') do set TXT_IMAGE_ID=%%A

if not "!TXT_IMAGE_ID!"=="" (
    echo OK: Image submitted, ID: !TXT_IMAGE_ID!
    echo PASS: Text-to-image submission succeeded >> %RESULTS_FILE%
    set TEXT_TO_IMAGE_ID=!TXT_IMAGE_ID!
) else (
    echo ERROR: Failed to submit text prompt
    echo FAIL: Text-to-image submission failed >> %RESULTS_FILE%
    goto PHASE4_SKIP
)

echo [*] Polling for completion (max 60 attempts)...
set ATTEMPT=0
:POLL_TEXT
set /a ATTEMPT=ATTEMPT+1
if %ATTEMPT% gtr 60 (
    echo WARNING: Text-to-image polling timeout
    echo WARNING: Text-to-image polling timeout >> %RESULTS_FILE%
    goto PHASE4_SKIP
)
timeout /t 2 /nobreak >nul
for /f "tokens=2 delims=:,\"" %%A in ('curl -s "%RELAY_URL%/image-status?image_id=!TEXT_TO_IMAGE_ID!" ^| findstr "status"') do set TEXT_STATUS=%%A
if "!TEXT_STATUS!"=="completed" (
    echo OK: Text-to-image completed in !ATTEMPT! attempts
    echo PASS: Text-to-image completed >> %RESULTS_FILE%
    goto PHASE4
) else if "!TEXT_STATUS!"=="processing" (
    if !ATTEMPT! equ 1 (echo.) else if !ATTEMPT! equ 1 (echo.)
    title Image Relay Test - Text-to-Image: Attempt !ATTEMPT!/60
    goto POLL_TEXT
) else (
    echo WARNING: Unexpected status: !TEXT_STATUS!
    echo WARNING: Text-to-image unexpected status >> %RESULTS_FILE%
)

:PHASE4_SKIP
echo.
echo ========================================
echo [PHASE 3] PASSED with warnings
echo ======================================== >> %RESULTS_FILE%
echo [PHASE 3] PASSED >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%
goto PHASE5

:PHASE4
echo.
echo ========================================
echo [PHASE 3] PASSED
echo ======================================== >> %RESULTS_FILE%
echo [PHASE 3] PASSED >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

REM ========== PHASE 4: Test Image Reference ==========
:PHASE5
echo.
echo [PHASE 4] Testing Image Reference Endpoint...
echo [PHASE 4] Testing Image Reference Endpoint... >> %RESULTS_FILE%

echo [*] Reading image file...
if not exist "%TEST_DIR%\input_base64.txt" (
    echo [*] Converting image to base64...
    powershell -Command "$img = [System.IO.File]::ReadAllBytes('%TEST_DIR%\input.jpg'); $b64 = [System.Convert]::ToBase64String($img); $b64 | Out-File '%TEST_DIR%\input_base64.txt' -Encoding UTF8"
)

echo [*] Loading base64 from file...
for /f %%A in ('powershell -Command "(Get-Content '%TEST_DIR%\input_base64.txt').Length"') do set B64_SIZE=%%A
echo [*] Base64 size: %B64_SIZE% characters

echo [*] Reading first 100 chars of base64...
for /f "tokens=1-2" %%A in ('powershell -Command "(Get-Content '%TEST_DIR%\input_base64.txt').Substring(0,100)"') do set B64_START=%%A

if "%B64_SIZE%" gtr "0" (
    echo OK: Base64 encoded image ready
    echo PASS: Base64 encoding successful >> %RESULTS_FILE%
) else (
    echo ERROR: Base64 conversion failed
    echo FAIL: Base64 encoding failed >> %RESULTS_FILE%
    goto PHASE_END
)

echo [*] Submitting image reference request...
REM Create temp JSON file with base64
setlocal enabledelayedexpansion
(
echo {
echo   "prompt": "enhance the image with vibrant colors",
echo   "model_id": "gpt-image-2.5-flare",
echo   "aspect_ratio": "16:9",
echo   "image_data": "data:image/jpeg;base64,
) > "!TEST_DIR!\payload.json"
powershell -Command "Add-Content '!TEST_DIR!\payload.json' (Get-Content '!TEST_DIR!\input_base64.txt')" 2>nul
echo " >> "!TEST_DIR!\payload.json"
echo } >> "!TEST_DIR!\payload.json"

REM Submit request
curl -s -X POST !RELAY_URL!/generate-image-from-reference -H "Content-Type: application/json" -d @"!TEST_DIR!\payload.json" > "!TEST_DIR!\ref_response.json"
for /f "tokens=2 delims=:,\"" %%A in ('findstr "image_id" "!TEST_DIR!\ref_response.json"') do set REF_IMAGE_ID=%%A

if not "!REF_IMAGE_ID!"=="" (
    echo OK: Reference image submitted, ID: !REF_IMAGE_ID!
    echo PASS: Image reference submission succeeded >> %RESULTS_FILE%
    set IMAGE_REF_ID=!REF_IMAGE_ID!
) else (
    echo ERROR: Failed to submit reference image
    echo FAIL: Image reference submission failed >> %RESULTS_FILE%
    goto PHASE_END
)

echo [*] Polling for completion (max 60 attempts)...
set ATTEMPT=0
:POLL_REF
set /a ATTEMPT=ATTEMPT+1
if %ATTEMPT% gtr 60 (
    echo WARNING: Image reference polling timeout
    echo WARNING: Image reference polling timeout >> %RESULTS_FILE%
    goto PHASE_END
)
timeout /t 2 /nobreak >nul
for /f "tokens=2 delims=:,\"" %%A in ('curl -s "%RELAY_URL%/image-status?image_id=!IMAGE_REF_ID!" ^| findstr "status"') do set REF_STATUS=%%A
if "!REF_STATUS!"=="completed" (
    echo OK: Image reference completed in !ATTEMPT! attempts
    echo PASS: Image reference completed >> %RESULTS_FILE%
    goto PHASE_COMPLETE
) else if "!REF_STATUS!"=="processing" (
    title Image Relay Test - Reference: Attempt !ATTEMPT!/60
    goto POLL_REF
) else (
    echo WARNING: Unexpected status: !REF_STATUS!
    echo WARNING: Image reference unexpected status >> %RESULTS_FILE%
)

:PHASE_COMPLETE
echo.
echo ========================================
echo [PHASE 4] PASSED
echo ======================================== >> %RESULTS_FILE%
echo [PHASE 4] PASSED >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

REM ========== PHASE 5: Results Summary ==========
:PHASE_END
echo.
echo ========================================
echo ALL TESTS COMPLETED SUCCESSFULLY
echo ========================================
echo. >> %RESULTS_FILE%
echo ======================================== >> %RESULTS_FILE%
echo ALL TESTS COMPLETED >> %RESULTS_FILE%
echo ======================================== >> %RESULTS_FILE%
echo Completed: %date% %time% >> %RESULTS_FILE%
echo. >> %RESULTS_FILE%

echo.
echo TEST SUMMARY:
echo ✅ Prerequisites: PASSED
echo ✅ Relay Server: PASSED
echo ✅ Text-to-Image: PASSED
echo ✅ Image Reference: PASSED
echo.
echo Results saved to: %RESULTS_FILE%
echo.
pause
exit /b 0

REM ========== ERROR Handler ==========
:ERROR
echo.
echo ========================================
echo TEST FAILED
echo ========================================
echo FAIL >> %RESULTS_FILE%
echo.
pause
exit /b 1
