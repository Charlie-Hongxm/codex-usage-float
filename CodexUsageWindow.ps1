Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

$ErrorActionPreference = "SilentlyContinue"

$CodexHome = Join-Path $env:USERPROFILE ".codex"
$SessionsRoot = Join-Path $CodexHome "sessions"
$StatePath = Join-Path $env:TEMP "codex-usage-float-state.json"

function Test-CodexRunning {
    $processes = Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq "codex" -or
        ($_.ProcessName -eq "ChatGPT" -and $_.Path -like "*OpenAI.Codex*")
    }
    return [bool]$processes
}

function Get-LatestTokenEvent {
    if (-not (Test-Path -LiteralPath $SessionsRoot)) {
        return $null
    }

    $latestFiles = Get-ChildItem -LiteralPath $SessionsRoot -Recurse -Filter "*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 8

    foreach ($file in $latestFiles) {
        $lines = Get-Content -LiteralPath $file.FullName -Tail 200 -ErrorAction SilentlyContinue
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            try {
                $event = $lines[$i] | ConvertFrom-Json -ErrorAction Stop
            } catch {
                continue
            }

            if ($event.payload.type -eq "token_count") {
                return [pscustomobject]@{
                    File = $file.FullName
                    Timestamp = $event.timestamp
                    Usage = $event.payload.info.total_token_usage
                    Last = $event.payload.info.last_token_usage
                    ContextWindow = $event.payload.info.model_context_window
                    RateLimits = $event.rate_limits
                }
            }
        }
    }

    return $null
}

function Format-Number([object]$value) {
    if ($null -eq $value) { return "未知" }
    try {
        return ([int64]$value).ToString("N0")
    } catch {
        return [string]$value
    }
}

function Get-DisplayState {
    $event = Get-LatestTokenEvent
    if ($null -eq $event) {
        return [pscustomobject]@{
            Title = "Codex 用量"
            Main = "等待用量事件"
            Detail = "尚未在本地 session 日志中发现 token_count。"
            Foot = "账户剩余额度以 Codex Settings / Usage 为准。"
            Percent = 0
        }
    }

    $total = [int64]($event.Usage.total_tokens)
    $context = [int64]($event.ContextWindow)
    $remaining = [Math]::Max(0, $context - $total)
    $percent = if ($context -gt 0) { [Math]::Min(100, [Math]::Round(($total / $context) * 100, 1)) } else { 0 }

    $limitText = "账户额度：本地日志未暴露"
    if ($event.RateLimits -and $event.RateLimits.primary) {
        $limitText = "主额度：" + ($event.RateLimits.primary | ConvertTo-Json -Compress)
    } elseif ($event.RateLimits -and $event.RateLimits.credits) {
        $limitText = "credits：" + ($event.RateLimits.credits | ConvertTo-Json -Compress)
    }

    return [pscustomobject]@{
        Title = "Codex 用量"
        Main = "上下文剩余 " + (Format-Number $remaining) + " token"
        Detail = "已用 " + (Format-Number $total) + " / " + (Format-Number $context) + " token"
        Foot = $limitText + "；最近更新 " + ([DateTime]$event.Timestamp).ToLocalTime().ToString("HH:mm:ss")
        Percent = $percent
    }
}

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Width="310" Height="132" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" Topmost="True" ShowInTaskbar="False"
        ResizeMode="NoResize">
  <Border CornerRadius="10" Background="#EE111827" BorderBrush="#554B5563" BorderThickness="1" Padding="14">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="8"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <DockPanel Grid.Row="0">
        <TextBlock Name="TitleText" Foreground="#FFD1D5DB" FontSize="12" FontWeight="SemiBold" DockPanel.Dock="Left"/>
        <Button Name="CloseButton" DockPanel.Dock="Right" Width="22" Height="22" Content="x"
                Foreground="#FFD1D5DB" Background="#22374151" BorderThickness="0" FontSize="12"/>
      </DockPanel>
      <TextBlock Name="MainText" Grid.Row="1" Margin="0,8,0,0" Foreground="#FFFFFFFF" FontSize="17" FontWeight="Bold"/>
      <TextBlock Name="DetailText" Grid.Row="2" Margin="0,4,0,0" Foreground="#FFD1D5DB" FontSize="12"/>
      <Grid Grid.Row="4">
        <Grid.RowDefinitions>
          <RowDefinition Height="6"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Border Grid.Row="0" Height="6" CornerRadius="3" Background="#334B5563"/>
        <Border Name="ProgressBar" Grid.Row="0" HorizontalAlignment="Left" Height="6" CornerRadius="3" Background="#FF22C55E" Width="0"/>
        <TextBlock Name="FootText" Grid.Row="1" Margin="0,8,0,0" Foreground="#FF9CA3AF" FontSize="10" TextWrapping="Wrap"/>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
$titleText = $window.FindName("TitleText")
$mainText = $window.FindName("MainText")
$detailText = $window.FindName("DetailText")
$footText = $window.FindName("FootText")
$progressBar = $window.FindName("ProgressBar")
$closeButton = $window.FindName("CloseButton")

$closeButton.Add_Click({ $window.Close() })
$window.Add_MouseLeftButtonDown({ $window.DragMove() })

$window.Left = [System.Windows.SystemParameters]::WorkArea.Right - $window.Width - 24
$window.Top = 72

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(5)
$timer.Add_Tick({
    if (-not (Test-CodexRunning)) {
        $window.Close()
        return
    }

    $state = Get-DisplayState
    $titleText.Text = $state.Title
    $mainText.Text = $state.Main
    $detailText.Text = $state.Detail
    $footText.Text = $state.Foot
    $progressBar.Width = [Math]::Max(0, [Math]::Min(282, 282 * ($state.Percent / 100)))
})

$timer.Start()
$state = Get-DisplayState
$titleText.Text = $state.Title
$mainText.Text = $state.Main
$detailText.Text = $state.Detail
$footText.Text = $state.Foot
$progressBar.Width = [Math]::Max(0, [Math]::Min(282, 282 * ($state.Percent / 100)))

$window.ShowDialog() | Out-Null
