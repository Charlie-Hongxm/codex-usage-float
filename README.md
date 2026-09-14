# Codex Usage Float

这是一个 Windows 桌面浮窗，用于显示 Codex 本地 session 日志中最近一次 `token_count` 事件。

## 显示内容

- 上下文窗口剩余 token：由 `model_context_window - total_tokens` 计算。
- 已用 token：来自本地 `~/.codex/sessions/**/*.jsonl`。
- 账户剩余额度：只有当 Codex 本地日志暴露 `rate_limits.primary` 或 `rate_limits.credits` 时才显示；否则显示“本地日志未暴露”。

## 安装

在 PowerShell 中运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-CodexUsageFloat.ps1
```

安装器会优先注册当前用户级 Windows Scheduled Task：`CodexUsageFloat`。如果系统策略拒绝访问 Task Scheduler，则自动在当前用户 Startup 文件夹写入 `CodexUsageFloat.vbs` 作为 fallback。它会在用户登录后常驻监测 Codex 进程；当 Codex 运行时显示浮窗，当 Codex 退出时关闭浮窗。

## 手动开启

```powershell
powershell -ExecutionPolicy Bypass -File .\Start-CodexUsageFloat.ps1
```

该命令会立即启动 watcher。如果 Codex 当前正在运行，浮窗会出现；如果 Codex 尚未运行，watcher 会等待 Codex 启动。

## 手动关闭

```powershell
powershell -ExecutionPolicy Bypass -File .\Stop-CodexUsageFloat.ps1
```

该命令只关闭当前正在运行的 watcher/浮窗，不删除登录自启动配置。下次登录后仍会自动启用。

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\Uninstall-CodexUsageFloat.ps1
```

卸载会删除自动启动配置，并停止当前 watcher/浮窗。

## 限制

OpenAI 官方文档没有提供稳定的本地 API 供第三方浮窗读取账号总剩余额度。本工具只读取本机日志中已经存在的信息，不读取或上传账号密钥。
