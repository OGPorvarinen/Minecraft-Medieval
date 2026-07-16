@echo off
setlocal EnableExtensions
chcp 65001 >nul

title Tesles MusicAI V8.22.2 - palautus ja 0:00-korjaus

set "PS1=%TEMP%\TeslesVoiceMusic-V8.22.2-RestoreAndFix.ps1"
set "URL=https://raw.githubusercontent.com/OGPorvarinen/Minecraft-Medieval/tesles-music-v8.22.2-hotfix/tesles-music-v8.22.2/TeslesVoiceMusic-V8.22.2-RestoreAndFix.ps1"

echo.
echo =================================================
echo  TESLES MUSICAI V8.22.2 - KORJAUS
echo =================================================
echo.
echo Ladataan turvallinen asennusskripti...

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%PS1%'; exit 0 } catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }"
if errorlevel 1 (
    echo.
    echo [VIRHE] Asennusskriptin lataaminen epaonnistui.
    echo Tarkista internet-yhteys ja yrita uudelleen.
    echo.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%" -InstallerFolder "%~dp0"
set "RESULT=%ERRORLEVEL%"

echo.
if not "%RESULT%"=="0" (
    echo [VIRHE] Paivitys epaonnistui. Vanha app.js palautetaan automaattisesti, jos se ehdittiin vaihtaa.
) else (
    echo [OK] Paivitys valmistui.
)
echo.
pause
exit /b %RESULT%
