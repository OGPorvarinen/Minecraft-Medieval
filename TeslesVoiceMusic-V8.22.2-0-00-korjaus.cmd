@echo off
setlocal EnableExtensions
chcp 65001 >nul
title TESLES MUSICAI V8.22.2 - 0:00 KORJAUS

net session >nul 2>&1
if not "%errorlevel%"=="0" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "ROOT=C:\TeslesVoiceMusicWorker"
set "APP=%ROOT%\app.js"

echo.
echo ================================================
echo  TESLES MUSICAI V8.22.2 - 0:00 KORJAUS
echo ================================================
echo.

if not exist "%APP%" (
  echo [VIRHE] Tiedostoa ei loydy: %APP%
  echo.
  pause
  exit /b 1
)

echo [1/4] Pysaytetaan kaynnissa oleva musiikkiworker...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; Get-CimInstance Win32_Process | Where-Object { $_.Name -ieq 'node.exe' -and $_.CommandLine -match 'TeslesVoiceMusicWorker.*app\.js' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }"
timeout /t 2 /nobreak >nul

echo [2/4] Varmuuskopioidaan app.js...
for /f "tokens=1-4 delims=/:. " %%a in ("%date% %time%") do set "STAMP=%%d%%b%%c_%%a"
copy /y "%APP%" "%APP%.backup-v8.22.2" >nul
attrib -R "%APP%" >nul 2>&1

echo [3/4] Korjataan aloitusajaksi 0:00...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$app='C:\TeslesVoiceMusicWorker\app.js';" ^
 "$utf8=New-Object System.Text.UTF8Encoding($false);" ^
 "$text=[System.IO.File]::ReadAllText($app);" ^
 "$old=$text;" ^
 "$text=$text.Replace('tuntematon kesto','0:00').Replace('Tuntematon kesto','0:00');" ^
 "if($text -eq $old){ Write-Host '[INFO] Tekstia tuntematon kesto ei loytynyt. Korjaus saattoi olla jo tiedostossa.' -ForegroundColor Yellow } else { [System.IO.File]::WriteAllText($app,$text,$utf8); Write-Host '[OK] Kaikki tuntematon kesto -kohdat vaihdettiin arvoon 0:00.' -ForegroundColor Green }"
if not "%errorlevel%"=="0" (
  echo [VIRHE] app.js-tiedoston muokkaus epaonnistui.
  copy /y "%APP%.backup-v8.22.2" "%APP%" >nul
  pause
  exit /b 1
)

echo [4/4] Kaynnistetaan musiikkiworker uudelleen...
set "NODE=%ROOT%\runtime\node.exe"
if not exist "%NODE%" set "NODE=node.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%NODE%' -ArgumentList '""%APP%""' -WorkingDirectory '%ROOT%' -WindowStyle Hidden"
timeout /t 3 /nobreak >nul

echo.
echo [OK] Korjaus asennettu.
echo Nyt soi -kohdan aloitusaika naytetaan muodossa 0:00.
echo Varmuuskopio: %APP%.backup-v8.22.2
echo.
pause
exit /b 0
