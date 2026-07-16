param(
    [string]$InstallerFolder = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Info([string]$Text) { Write-Host "[INFO] $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "[OK]   $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "[VAROITUS] $Text" -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host "[VIRHE] $Text" -ForegroundColor Red }

# Pyydä järjestelmänvalvojan oikeudet vain tarvittaessa.
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $PSCommandPath + '"'))
    if ($InstallerFolder) {
        $args += @('-InstallerFolder', ('"' + $InstallerFolder + '"'))
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList ($args -join ' ')
    exit
}

$workerRoot = 'C:\TeslesVoiceMusicWorker'
$targetApp = Join-Path $workerRoot 'app.js'
$nodeExe = Join-Path $workerRoot 'runtime\node.exe'
if (-not (Test-Path $nodeExe)) {
    $nodeExe = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
}

if ([string]::IsNullOrWhiteSpace($InstallerFolder)) {
    $InstallerFolder = Split-Path -Parent $PSCommandPath
}

Write-Host ''
Write-Host '=================================================' -ForegroundColor DarkCyan
Write-Host ' TESLES MUSICAI V8.22.2 - PALAUTUS JA 0:00-KORJAUS' -ForegroundColor Cyan
Write-Host '=================================================' -ForegroundColor DarkCyan
Write-Host ''

if (-not (Test-Path $workerRoot)) {
    throw "Kansiota $workerRoot ei löytynyt."
}

# Etsi käyttäjän antama tunnetusti toimiva V8.22-paketti samasta kansiosta.
$zip = Get-ChildItem -LiteralPath $InstallerFolder -File -Filter '*.zip' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*V8.22*Spotify-esilataus*' } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $zip) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Valitse Tesles Voice Music V8.22 - Spotify-esilataus ja varma toisto.zip'
    $dialog.Filter = 'ZIP-paketit (*.zip)|*.zip'
    $dialog.InitialDirectory = $InstallerFolder
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'V8.22 ZIP-pakettia ei valittu.'
    }
    $zip = Get-Item -LiteralPath $dialog.FileName
}

Write-Info "Käytetään palautuspakettia: $($zip.Name)"

$tempRoot = Join-Path $env:TEMP ('TeslesMusicV8222_' + [guid]::NewGuid().ToString('N'))
$extractRoot = Join-Path $tempRoot 'extract'
$patchedApp = Join-Path $tempRoot 'app.js'
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

$backup = $null
$installed = $false
try {
    Expand-Archive -LiteralPath $zip.FullName -DestinationPath $extractRoot -Force

    $sourceApp = Get-ChildItem -LiteralPath $extractRoot -Recurse -File -Filter 'app.js' |
        Where-Object { $_.FullName -notmatch '\\node_modules\\' } |
        Sort-Object Length -Descending |
        Select-Object -First 1

    if (-not $sourceApp) {
        throw 'V8.22-paketista ei löytynyt app.js-tiedostoa.'
    }

    Write-Info "Palautetaan app.js paketista: $($sourceApp.FullName)"

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $appText = [System.IO.File]::ReadAllText($sourceApp.FullName, [System.Text.Encoding]::UTF8)

    # Muuta vain näkyvä puuttuvan keston teksti. Ei kosketa toimintoihin tai syntaksiin.
    $patchedText = [System.Text.RegularExpressions.Regex]::Replace(
        $appText,
        'tuntematon kesto',
        '0:00',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    [System.IO.File]::WriteAllText($patchedApp, $patchedText, $utf8NoBom)

    if (-not $nodeExe -or -not (Test-Path $nodeExe)) {
        throw 'Node.js-ohjelmaa ei löytynyt syntaksitarkistusta varten.'
    }

    Write-Info 'Tarkistetaan app.js:n JavaScript-syntaksi...'
    $checkOutput = & $nodeExe --check $patchedApp 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Syntaksitarkistus epäonnistui:`n$($checkOutput -join [Environment]::NewLine)"
    }
    Write-Ok 'JavaScript-syntaksi on kunnossa.'

    # Sulje vain tämän workerin Node-prosessi, ei käyttäjän muita Node-ohjelmia.
    Write-Info 'Pysäytetään nykyinen Tesles-musiikkiworker...'
    Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and (
                $_.CommandLine -like '*TeslesVoiceMusicWorker*app.js*' -or
                $_.CommandLine -like '*C:\TeslesVoiceMusicWorker\app.js*'
            )
        } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    Start-Sleep -Milliseconds 800

    if (Test-Path $targetApp) {
        $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $backup = Join-Path $workerRoot ("app.js.backup-$stamp")
        Copy-Item -LiteralPath $targetApp -Destination $backup -Force
        Write-Ok "Vanha app.js varmuuskopioitiin: $backup"
    }

    Copy-Item -LiteralPath $patchedApp -Destination $targetApp -Force
    $installed = $true
    Write-Ok 'Toimiva V8.22 app.js palautettiin ja 0:00-korjaus asennettiin.'

    Write-Info 'Käynnistetään musiikkiworker...'
    $process = Start-Process -FilePath $nodeExe -ArgumentList @('app.js') -WorkingDirectory $workerRoot -WindowStyle Hidden -PassThru
    Start-Sleep -Seconds 3

    $process.Refresh()
    if ($process.HasExited) {
        throw "Worker sammui heti käynnistyksen jälkeen (ExitCode $($process.ExitCode))."
    }

    Write-Ok "Musiikkiworker käynnistyi onnistuneesti. PID: $($process.Id)"
    Write-Host ''
    Write-Host 'Päivitys valmis. Paneelissa puuttuva kesto näkyy nyt muodossa 0:00.' -ForegroundColor Green
}
catch {
    Write-Fail $_.Exception.Message

    if ($installed -and $backup -and (Test-Path $backup)) {
        try {
            Copy-Item -LiteralPath $backup -Destination $targetApp -Force
            Write-Warn 'Korjaus epäonnistui, joten vanha app.js palautettiin automaattisesti.'
            if ($nodeExe -and (Test-Path $nodeExe)) {
                Start-Process -FilePath $nodeExe -ArgumentList @('app.js') -WorkingDirectory $workerRoot -WindowStyle Hidden | Out-Null
            }
        }
        catch {
            Write-Fail 'Myös automaattinen palautus epäonnistui.'
        }
    }
    exit 1
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
