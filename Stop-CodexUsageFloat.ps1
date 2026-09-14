$ErrorActionPreference = "SilentlyContinue"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatcherScript = Join-Path $ScriptRoot "CodexUsageWatcher.ps1"
$WindowScript = Join-Path $ScriptRoot "CodexUsageWindow.ps1"

$escapedWatcher = $WatcherScript.Replace('\', '\\')
$escapedWindow = $WindowScript.Replace('\', '\\')

Get-CimInstance Win32_Process | Where-Object {
    $_.Name -like "powershell*" -and (
        $_.CommandLine -like "*CodexUsageWatcher.ps1*" -or
        $_.CommandLine -like "*CodexUsageWindow.ps1*" -or
        $_.CommandLine -like "*$escapedWatcher*" -or
        $_.CommandLine -like "*$escapedWindow*"
    )
} | ForEach-Object {
    Stop-Process -Id $_.ProcessId -Force
}

Write-Host "Stopped CodexUsageFloat watcher/window"
