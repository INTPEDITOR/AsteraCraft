@echo off
cd /d "%~dp0"
if not exist "AsteraCraft.exe" (
  echo AsteraCraft.exe was not found. Extract the full Windows ZIP first.
  pause
  exit /b 1
)
start "" "%~dp0AsteraCraft.exe" --main-pack "%~dp0AsteraCraft.pck"
