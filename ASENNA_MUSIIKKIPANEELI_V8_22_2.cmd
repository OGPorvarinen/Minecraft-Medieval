@echo off
setlocal
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-ControlPanel-V8-22-2.ps1"
if errorlevel 1 (
  echo.
  echo Paivitys epaonnistui.
  pause
  exit /b 1
)

echo.
echo Paivitys valmis.
timeout /t 3 /nobreak >nul
exit /b 0
