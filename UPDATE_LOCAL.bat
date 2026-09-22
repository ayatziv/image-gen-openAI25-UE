@echo off
REM Auto-Update Local Folder from GitHub

echo.
echo ========================================
echo  UPDATING LOCAL FOLDER FROM GITHUB
echo ========================================
echo.

cd /d "%~dp0"

echo [*] Pulling latest changes...
git pull origin main

echo.
echo [*] Checking status...
git status

echo.
echo ========================================
echo  UPDATE COMPLETE
echo ========================================
echo.
echo Local folder is now synchronized with GitHub
echo.
pause
