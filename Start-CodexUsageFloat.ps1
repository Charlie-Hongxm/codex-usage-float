$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatcherScript = Join-Path $ScriptRoot "CodexUsageWatcher.ps1"

if (-not (Test-Path -LiteralPath $WatcherScript)) {
    throw "Cannot find $WatcherScript"
}

Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", $WatcherScript) `
    -WindowStyle Hidden

Write-Host "Started CodexUsageFloat watcher"
