#!/bin/bash
set -euo pipefail

# status.sh — Check service status
# Supports macOS launchd and Linux systemd.
# Usage: status.sh [service-name]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_detect.sh"

if [[ $# -ge 1 ]]; then
  SERVICE_NAME="$1"
  set_paths "$SERVICE_NAME"

  if [[ "$BACKEND" == "launchd" ]]; then
    if [[ ! -f "$PLIST_PATH" ]]; then
      echo "Service '${SERVICE_NAME}' is not installed."
      exit 1
    fi

    echo "Service: ${SERVICE_NAME}"
    echo "Label:   ${LABEL}"
    echo "Plist:   ${PLIST_PATH}"
    echo "Backend: launchd"

    if launchctl list "$LABEL" &>/dev/null; then
      echo "State:   running"
      launchctl list "$LABEL" 2>/dev/null
    else
      echo "State:   stopped"
    fi

    if [[ -d "$LOG_DIR" ]]; then
      echo ""
      echo "Last 5 lines of stderr:"
      tail -5 "$LOG_DIR/stderr.log" 2>/dev/null || echo "  (no stderr log)"
    fi

  else
    if [[ ! -f "$UNIT_PATH" ]]; then
      echo "Service '${SERVICE_NAME}' is not installed."
      exit 1
    fi

    echo "Service: ${SERVICE_NAME}"
    echo "Label:   ${LABEL}"
    echo "Unit:    ${UNIT_PATH}"
    echo "Backend: systemd"
    echo "State:   $(systemctl --user is-active "$LABEL" 2>/dev/null || echo 'unknown')"
    echo ""
    systemctl --user status "$LABEL" --no-pager 2>/dev/null || true
  fi

else
  # Show all toolguard services
  echo "All ai.toolguard.* services (${BACKEND}):"
  echo ""

  if [[ "$BACKEND" == "launchd" ]]; then
    launchctl list | grep "ai\.toolguard\." || echo "  (none found)"
  else
    systemctl --user list-units --type=service --all 'ai.toolguard.*' --no-pager 2>/dev/null \
      | grep "ai\.toolguard\." || echo "  (none found)"
  fi
fi
