param(
    [string]$Root = "C:\TeslesVoiceMusicWorker"
)

$ErrorActionPreference = "Stop"

$appFile = Join-Path $Root "app.js"
$nodeExe = Join-Path $Root "runtime\node.exe"
$logDir = Join-Path $Root "logs"

if (-not (Test-Path -LiteralPath $appFile)) {
    throw "app.js puuttuu polusta $appFile"
}

if (-not (Test-Path -LiteralPath $nodeExe)) {
    $nodeExe = (Get-Command node -ErrorAction Stop).Source
}

$text = [IO.File]::ReadAllText($appFile, [Text.Encoding]::UTF8)
$originalText = $text
$lines = $text -split "\r\n|\n|\r"
$changeCount = 0

$idPattern = '(?i)music_panel_(?:volume|vol)_(?:down|up|minus|plus|decrease|increase)'

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -notmatch $idPattern) { continue }

    $last = [Math]::Min($lines.Count - 1, $i + 40)
    for ($j = $i; $j -le $last; $j++) {
        $before = $lines[$j]
        $after = $before

        if ($before -match '(?i)(volume|vol|setVolume|changeVolume|adjustVolume)' -and $before -match '(?<!\d)10(?!\d)') {
            $after = [regex]::Replace($after, '(?<!\d)10(?!\d)', '5')
        }

        if ($after -match '(?i)(volume|vol|setVolume|changeVolume|adjustVolume)' -and $after -match '(?<!\d)0\.1(?!\d)') {
            $after = [regex]::Replace($after, '(?<!\d)0\.1(?!\d)', '0.05')
        }

        $after = $after.Replace('-10%', '-5%').Replace('+10%', '+5%')

        if ($after -ne $before) {
            $lines[$j] = $after
            $changeCount++
        }
    }
}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $before = $lines[$i]
    $after = $before

    if ($before -match '(?i)(volume|vol).*(step|increment|decrement)' -and $before -match '(?<!\d)10(?!\d)') {
        $after = [regex]::Replace($after, '(?<!\d)10(?!\d)', '5')
    }

    $after = $after.Replace('Vol -10%', 'Vol -5%').Replace('Vol +10%', 'Vol +5%')

    if ($after -ne $before) {
        $lines[$i] = $after
        $changeCount++
    }
}

if ($changeCount -eq 0) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $before = $lines[$i]
        $after = $before

        if ($before -match '(?i)(setVolume|changeVolume|adjustVolume|volumePercent|musicVolume|\.volume)' -and $before -match '(?:\+|-)\s*10(?!\d)') {
            $after = [regex]::Replace($after, '((?:\+|-)\s*)10(?!\d)', '${1}5')
        }

        if ($before -match '(?i)(setVolume|changeVolume|adjustVolume|volumePercent|musicVolume|\.volume)' -and $before -match '(?:\+|-)\s*0\.1(?!\d)') {
            $after = [regex]::Replace($after, '((?:\+|-)\s*)0\.1(?!\d)', '${1}0.05')
        }

        if ($after -ne $before) {
            $lines[$i] = $after
            $changeCount++
        }
    }
}

if ($changeCount -eq 0) {
    throw "Aanensaadon 10 prosentin askelta ei loytynyt. app.js:aa ei muutettu."
}

$newText = [string]::Join([Environment]::NewLine, $lines)
if ($newText -eq $originalText) {
    throw "Muutosta ei syntynyt. app.js:aa ei muutettu."
}

$backupFile = "$appFile.v8.22.3.backup"
$tempFile = Join-Path $Root "app.v8.22.3.tmp.js"

Copy-Item -LiteralPath $appFile -Destination $backupFile -Force
[IO.File]::WriteAllText($tempFile, $newText, (New-Object Text.UTF8Encoding($false)))

& $nodeExe --check $tempFile | Out-Null
if ($LASTEXITCODE -ne 0) {
    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
    throw "Uuden app.js:n syntaksitarkistus epaonnistui. Vanha versio jai kayttoon."
}

Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -like '*TeslesVoiceMusicWorker*app.js*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Milliseconds 700
Move-Item -LiteralPath $tempFile -Destination $appFile -Force

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

Start-Process -FilePath $nodeExe `
    -ArgumentList "app.js" `
    -WorkingDirectory $Root `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $logDir "worker-out.log") `
    -RedirectStandardError (Join-Path $logDir "worker-error.log")

Start-Sleep -Seconds 3

$running = Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -and $_.CommandLine -like '*TeslesVoiceMusicWorker*app.js*' } |
    Select-Object -First 1

if (-not $running) {
    Copy-Item -LiteralPath $backupFile -Destination $appFile -Force
    Start-Process -FilePath $nodeExe -ArgumentList "app.js" -WorkingDirectory $Root -WindowStyle Hidden
    throw "Uusi versio ei kaynnistynyt. Vanha app.js palautettiin automaattisesti."
}

Write-Host "Valmis. Paneelin aanenvoimakkuus muuttuu nyt 5 prosenttia kerrallaan."
