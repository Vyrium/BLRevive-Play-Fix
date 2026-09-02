@echo off
setlocal
cd /d "%~dp0"
set "SCRIPT=%~dp0scripts\BLReviveInstaller.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: The installer support files are incomplete.
  echo Re-extract the full BLRevive Steam Play Fix package and try again.
  echo.
  pause
  exit /b 1
)
if not exist "%~dp0payload\BLReviveSteamLauncher.exe" (
  echo ERROR: The prebuilt player payload is missing.
  echo.
  echo This is probably GitHub's source-code archive, not the player release.
  echo Download the latest release ZIP from:
  echo https://github.com/Vyrium/BLRevive-Play-Fix/releases
  echo.
  pause
  exit /b 1
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
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
