@echo off
cd /d "%~dp0"
if exist "%~dp0runtime\node.exe" (
  "%~dp0runtime\node.exe" "%~dp0server\server.js"
) else if exist "%ProgramFiles%\nodejs\node.exe" (
  "%ProgramFiles%\nodejs\node.exe" "%~dp0server\server.js"
) else (
  where node >nul 2>nul
  if errorlevel 1 (
    echo Node.js 24 or newer is required to host multiplayer.
    echo Install from https://nodejs.org then run this file again.
    pause
    exit /b 1
  )
  node "%~dp0server\server.js"
)
pause
