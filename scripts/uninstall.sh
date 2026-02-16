#!/bin/bash
set -euo pipefail

# uninstall.sh — Stop and remove a user service
# Supports macOS launchd and Linux systemd.
# Usage: uninstall.sh <service-name>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_detect.sh"

[[ $# -lt 1 ]] && { echo "Usage: $0 <service-name>"; exit 1; }

SERVICE_NAME="$1"
set_paths "$SERVICE_NAME"

if [[ "$BACKEND" == "launchd" ]]; then
  if [[ ! -f "$PLIST_PATH" ]]; then
    echo "Error: Service '${SERVICE_NAME}' not found (no plist at ${PLIST_PATH})"
    exit 1
  fi

  echo "Unloading service '${SERVICE_NAME}'..."
  launchctl unload "$PLIST_PATH" 2>/dev/null || true
  rm -f "$PLIST_PATH"

  echo "Service '${SERVICE_NAME}' uninstalled."
  echo "Logs preserved at: ~/Library/Logs/toolguard/${SERVICE_NAME}/"

else
  if [[ ! -f "$UNIT_PATH" ]]; then
    echo "Error: Service '${SERVICE_NAME}' not found (no unit at ${UNIT_PATH})"
    exit 1
  fi

  echo "Stopping service '${SERVICE_NAME}'..."
  systemctl --user disable --now "$LABEL" 2>/dev/null || true
  rm -f "$UNIT_PATH"
  systemctl --user daemon-reload

  echo "Service '${SERVICE_NAME}' uninstalled."
  echo "Logs preserved at: ${LOG_DIR}/"
fi
