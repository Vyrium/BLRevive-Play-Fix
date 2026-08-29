@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
set "RC=%ERRORLEVEL%"
echo.
if not "%RC%"=="0" (
  echo Installation did not complete successfully. Error code: %RC%
) else (
  echo Installation completed successfully.
)
echo.
pause
exit /b %RC%
