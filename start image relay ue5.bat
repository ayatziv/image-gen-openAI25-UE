@echo off
REM Image Generation Relay Launcher
REM Double-click this file to start the relay on port 3001

echo.
echo ========================================
echo  11 Labs Image Generation Relay
echo  GPT Image 2.5 for Unreal Engine 5
echo ========================================
echo.

REM Check if Node.js is installed
node --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    echo.
    pause
    exit /b 1
)

REM Check if dependencies are installed
if not exist "node_modules" (
    echo Installing dependencies...
    call npm install
    echo.
)

REM Check if .env file exists
if not exist ".env" (
    echo ERROR: .env file not found!
    echo Please copy .env.example to .env and add your API key:
    echo   ELEVENLABS_API_KEY=your_api_key_here
    echo.
    pause
    exit /b 1
)

REM Start the relay
echo Starting Image Generation Relay...
echo Listening on http://localhost:3001
echo.
echo Keep this window open. Close it to stop the relay.
echo.

node relay.js

pause
