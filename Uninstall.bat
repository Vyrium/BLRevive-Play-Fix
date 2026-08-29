@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo Uninstall did not complete successfully. Error code: %RC%
) else (
  echo Uninstall completed successfully.
)
echo.
pause
exit /b %RC%
