@echo off
setlocal EnableExtensions
title Tesles Music V8.22.3 - 5 prosentin aanenvoimakkuus

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Volume-Step-5.ps1"

if errorlevel 1 (
  echo.
  echo Paivitys epaonnistui. Botti palautettiin tarvittaessa vanhaan versioon.
  pause
  exit /b 1
)

echo.
echo Valmis. Aanenvoimakkuus muuttuu nyt 5%% kerrallaan.
pause
