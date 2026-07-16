$ErrorActionPreference = 'Stop'

$root = 'C:\TeslesVoiceMusicWorker'
$app = Join-Path $root 'app.js'
$node = Join-Path $root 'runtime\node.exe'
$pidFile = Join-Path $root 'worker.pid'

if (-not (Test-Path -LiteralPath $app)) {
    throw "app.js ei loydy: $app"
}
if (-not (Test-Path -LiteralPath $node)) {
    throw "node.exe ei loydy: $node"
}

function Test-AppSyntax([string]$path) {
    & $node --check $path *> $null
    return ($LASTEXITCODE -eq 0)
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $root "app.js.backup-v8.22.2-$stamp"
Copy-Item -LiteralPath $app -Destination $backup -Force

if (-not (Test-AppSyntax $app)) {
    $restored = $false
    $candidates = Get-ChildItem -LiteralPath $root -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $app -and $_.Name -like 'app.js*' } |
        Sort-Object LastWriteTime -Descending

    foreach ($candidate in $candidates) {
        if (Test-AppSyntax $candidate.FullName) {
            Copy-Item -LiteralPath $candidate.FullName -Destination $app -Force
            $restored = $true
            break
        }
    }

    if (-not $restored) {
        throw 'Nykyinen app.js on rikki eika toimivaa varmuuskopiota loytynyt.'
    }
}

if (Test-Path -LiteralPath $pidFile) {
    try {
        $workerPid = [int](Get-Content -LiteralPath $pidFile -Raw).Trim()
        Stop-Process -Id $workerPid -Force -ErrorAction SilentlyContinue
    } catch {}
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match '^node(\.exe)?$' -and
        $_.CommandLine -and
        $_.CommandLine -like '*TeslesVoiceMusicWorker*app.js*'
    } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Start-Sleep -Milliseconds 700

$text = [System.IO.File]::ReadAllText($app, [System.Text.Encoding]::UTF8)
$updated = [System.Text.RegularExpressions.Regex]::Replace(
    $text,
    'tuntematon kesto',
    '0:00',
    [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($app, $updated, $utf8NoBom)

if (-not (Test-AppSyntax $app)) {
    Copy-Item -LiteralPath $backup -Destination $app -Force
    throw 'Paivitetyn app.js-tiedoston syntaksitarkistus epaonnistui. Vanha versio palautettiin.'
}

$process = Start-Process -FilePath $node -ArgumentList 'app.js' -WorkingDirectory $root -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 3

if ($process.HasExited) {
    Copy-Item -LiteralPath $backup -Destination $app -Force
    Start-Process -FilePath $node -ArgumentList 'app.js' -WorkingDirectory $root -WindowStyle Hidden | Out-Null
    throw 'Uusi versio ei kaynnistynyt. Vanha app.js palautettiin ja kaynnistettiin.'
}

Write-Host 'Tesles Music V8.22.2 paivitetty ja kaynnistetty.'
