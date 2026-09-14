$ErrorActionPreference = "SilentlyContinue"

$TaskName = "CodexUsageFloat"
$StartupVbs = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup\CodexUsageFloat.vbs"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$StopScript = Join-Path $ScriptRoot "Stop-CodexUsageFloat.ps1"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
Remove-Item -LiteralPath $StartupVbs -Force

if (Test-Path -LiteralPath $StopScript) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $StopScript
}

Write-Host "Uninstalled $TaskName"
