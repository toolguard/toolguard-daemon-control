---
name: toolguard-daemon-control
description: Manage long-running processes as persistent user services. Supports macOS launchd and Linux systemd. Use when asked to start, stop, restart, check status of, or manage background services/daemons. Handles service file creation, lifecycle, and log access. Use this instead of background exec for any process that should persist beyond the current session.
---

# toolguard-daemon-control

Manage any executable as a persistent user service on macOS (launchd) or Linux (systemd).

## Overview

The scripts automatically detect the OS and use the appropriate backend:

- **macOS**: launchd user agents at `~/Library/LaunchAgents/ai.toolguard.<name>.plist`
- **Linux**: systemd user units at `~/.config/systemd/user/ai.toolguard.<name>.service`

Services auto-restart on failure and support file-based logging on both platforms.

## Scripts

All scripts are in `scripts/` relative to this skill's directory. Run them with `bash`.

### install.sh — Create and start a service

```bash
bash scripts/install.sh <service-name> <command> [args...] [--workdir <dir>] [--env KEY=VALUE ...]
```

- `service-name`: Short identifier (e.g., `toolguard-proxy`).
- `command`: Absolute path to the executable (or a command in $PATH).
- `args`: Arguments passed to the command.
- `--workdir <dir>`: Working directory for the process (default: `$HOME`).
- `--env KEY=VALUE`: Environment variables (repeatable).

Example:
```bash
bash scripts/install.sh toolguard-proxy /usr/local/go/bin/go run ./cmd/server --config toolguard.dev.yaml --workdir ~/Documents/toolguard
```

### uninstall.sh — Stop and remove a service

```bash
bash scripts/uninstall.sh <service-name>
```

Stops and removes the service. Logs are preserved.

### status.sh — Check service status

```bash
bash scripts/status.sh [service-name]
```

Without arguments, lists all `ai.toolguard.*` services. With a name, shows detailed status.

### logs.sh — View service logs

```bash
bash scripts/logs.sh <service-name> [--follow] [--lines <n>] [--journald]
```

Shows stdout and stderr logs. Default: last 50 lines.

On Linux, use `--journald` (or `-j`) to view logs via `journalctl` instead of file-based logs.

### list.sh — List all managed services

```bash
bash scripts/list.sh
```

Lists all installed `ai.toolguard.*` services with their running state.

## Platform Notes

### macOS (launchd)
- Services run as the current user (no sudo required).
- `KeepAlive = true` for auto-restart.
- Log directory: `~/Library/Logs/toolguard/<service-name>/`
- Plist location: `~/Library/LaunchAgents/ai.toolguard.<service-name>.plist`

### Linux (systemd)
- Uses `systemctl --user` (no sudo required).
- `Restart=always` with `RestartSec=5`.
- Unit file: `~/.config/systemd/user/ai.toolguard.<service-name>.service`
- File-based logs: `~/.local/share/toolguard/<service-name>/`
- Journal logs: `journalctl --user -u ai.toolguard.<service-name>`
- Requires user lingering for services to persist after logout: `loginctl enable-linger $USER`

## General Notes

- To run a Go project, use the compiled binary path or wrap in a shell script — launchd does not support `go run` directly. Use `go build` first, then point to the binary.
