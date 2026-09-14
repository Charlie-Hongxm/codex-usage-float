$ErrorActionPreference = "SilentlyContinue"

$createdMutex = $false
$mutex = New-Object System.Threading.Mutex($true, "CodexUsageFloatWatcher", [ref]$createdMutex)
if (-not $createdMutex) {
    exit 0
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$WindowScript = Join-Path $ScriptRoot "CodexUsageWindow.ps1"
$WindowProcess = $null

function Test-CodexRunning {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq "codex" -or
        ($_.ProcessName -eq "ChatGPT" -and $_.Path -like "*OpenAI.Codex*")
    }
    return [bool]$processes
}

while ($true) {
    $codexRunning = Test-CodexRunning
    $windowAlive = $false

    if ($WindowProcess -and -not $WindowProcess.HasExited) {
        $windowAlive = $true
    }

    if ($codexRunning -and -not $windowAlive -and (Test-Path -LiteralPath $WindowScript)) {
        $WindowProcess = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", $WindowScript) `
            -WindowStyle Hidden `
            -PassThru
    }

    if (-not $codexRunning -and $windowAlive) {
        Stop-Process -Id $WindowProcess.Id -Force
        $WindowProcess = $null
    }

    Start-Sleep -Seconds 5
}
