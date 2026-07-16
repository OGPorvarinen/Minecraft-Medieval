@echo off
setlocal EnableExtensions
title Tesles Music V8.22.2 paivitys

set "ROOT=C:\TeslesVoiceMusicWorker"
set "ZIP=%~dp0Tesles Voice Music V8.22 - Spotify-esilataus ja varma toisto.zip"
set "TMPDIR=%TEMP%\TeslesMusicV8222"
set "NODE=%ROOT%\runtime\node.exe"

if not exist "%ZIP%" (
  echo VIRHE: V8.22 ZIP ei ole samassa kansiossa taman BAT-tiedoston kanssa.
  pause
  exit /b 1
)

if not exist "%ROOT%" (
  echo VIRHE: Kansio %ROOT% puuttuu.
  pause
  exit /b 1
)

if not exist "%NODE%" set "NODE=node"

rmdir /s /q "%TMPDIR%" >nul 2>&1
mkdir "%TMPDIR%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%TMPDIR%' -Force; $app = Get-ChildItem -LiteralPath '%TMPDIR%' -Filter app.js -File -Recurse | Select-Object -First 1; if (-not $app) { exit 2 }; $text = [IO.File]::ReadAllText($app.FullName, [Text.Encoding]::UTF8); $text = $text.Replace('tuntematon kesto','0:00'); [IO.File]::WriteAllText($app.FullName, $text, (New-Object Text.UTF8Encoding($false))); Copy-Item -LiteralPath $app.FullName -Destination '%ROOT%\app.js.new' -Force"

if errorlevel 1 (
  echo VIRHE: app.js:n valmistelu epaonnistui.
  pause
  exit /b 1
)

"%NODE%" --check "%ROOT%\app.js.new" >nul 2>&1
if errorlevel 1 (
  del /q "%ROOT%\app.js.new" >nul 2>&1
  echo VIRHE: Uuden app.js:n syntaksi ei kelpaa. Vanhaa ei muutettu.
  pause
  exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='node.exe'\" | Where-Object { $_.CommandLine -and $_.CommandLine -like '*TeslesVoiceMusicWorker*app.js*' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"

timeout /t 1 /nobreak >nul

if exist "%ROOT%\app.js" copy /y "%ROOT%\app.js" "%ROOT%\app.js.backup" >nul
move /y "%ROOT%\app.js.new" "%ROOT%\app.js" >nul

if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process -FilePath '%NODE%' -ArgumentList 'app.js' -WorkingDirectory '%ROOT%' -WindowStyle Hidden -RedirectStandardOutput '%ROOT%\logs\worker-out.log' -RedirectStandardError '%ROOT%\logs\worker-error.log'"

timeout /t 3 /nobreak >nul
rmdir /s /q "%TMPDIR%" >nul 2>&1

echo Valmis. Tesles Music paivitettiin V8.22.2-versioon.
pause
