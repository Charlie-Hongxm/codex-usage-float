$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WatcherScript = Join-Path $ScriptRoot "CodexUsageWatcher.ps1"
$TaskName = "CodexUsageFloat"
$StartupDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Startup"
$StartupVbs = Join-Path $StartupDir "CodexUsageFloat.vbs"

if (-not (Test-Path -LiteralPath $WatcherScript)) {
    throw "Cannot find $WatcherScript"
}

try {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$WatcherScript`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel LeastPrivilege
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DisallowStartIfOnBatteries:$false -ExecutionTimeLimit (New-TimeSpan -Days 3650)

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Installed and started scheduled task $TaskName"
} catch {
    New-Item -ItemType Directory -Force -Path $StartupDir | Out-Null
    $escapedWatcher = $WatcherScript.Replace('"', '""')
    $vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File " & Chr(34) & "$escapedWatcher" & Chr(34), 0, False
"@
    Set-Content -LiteralPath $StartupVbs -Value $vbs -Encoding ASCII
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$StartupVbs`"" -WindowStyle Hidden
    Write-Host "Scheduled task unavailable; installed and started Startup launcher $StartupVbs"
}
