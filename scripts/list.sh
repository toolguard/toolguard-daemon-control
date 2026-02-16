#!/bin/bash
set -euo pipefail

# list.sh — List all managed toolguard services
# Supports macOS launchd and Linux systemd.
# Usage: list.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_detect.sh"

FOUND=false

if [[ "$BACKEND" == "launchd" ]]; then
  PLIST_DIR="$HOME/Library/LaunchAgents"

  for plist in "$PLIST_DIR"/ai.toolguard.*.plist; do
    [[ -f "$plist" ]] || continue
    FOUND=true

    LABEL=$(basename "$plist" .plist)
    SERVICE_NAME="${LABEL#ai.toolguard.}"

    if launchctl list "$LABEL" &>/dev/null; then
      STATE="running"
    else
      STATE="stopped"
    fi

    printf "%-30s %-10s %s\n" "$SERVICE_NAME" "$STATE" "(launchd)"
  done

else
  UNIT_DIR="$HOME/.config/systemd/user"

  for unit in "$UNIT_DIR"/ai.toolguard.*.service; do
    [[ -f "$unit" ]] || continue
    FOUND=true

    LABEL=$(basename "$unit" .service)
    SERVICE_NAME="${LABEL#ai.toolguard.}"
    STATE=$(systemctl --user is-active "$LABEL" 2>/dev/null || echo "unknown")

    printf "%-30s %-10s %s\n" "$SERVICE_NAME" "$STATE" "(systemd)"
  done
fi

if [[ "$FOUND" == "false" ]]; then
  echo "No toolguard services installed."
fi
