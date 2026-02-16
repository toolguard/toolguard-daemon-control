#!/bin/bash
set -euo pipefail

# logs.sh — View service logs
# Supports macOS launchd and Linux systemd.
# Usage: logs.sh <service-name> [--follow] [--lines <n>] [--journald]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_detect.sh"

[[ $# -lt 1 ]] && { echo "Usage: $0 <service-name> [--follow] [--lines <n>] [--journald]"; exit 1; }

SERVICE_NAME="$1"; shift
set_paths "$SERVICE_NAME"
LINES=50
FOLLOW=false
USE_JOURNALD=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --follow|-f) FOLLOW=true; shift ;;
    --lines|-n) LINES="$2"; shift 2 ;;
    --journald|-j) USE_JOURNALD=true; shift ;;
    *) shift ;;
  esac
done

# On systemd, --journald flag (or missing log dir) uses journalctl
if [[ "$BACKEND" == "systemd" && ( "$USE_JOURNALD" == "true" || ! -d "$LOG_DIR" ) ]]; then
  echo "=== journalctl for ${LABEL} ==="
  if [[ "$FOLLOW" == "true" ]]; then
    journalctl --user -u "$LABEL" -n "$LINES" -f
  else
    journalctl --user -u "$LABEL" -n "$LINES" --no-pager
  fi
  exit 0
fi

# File-based logs (both backends)
if [[ ! -d "$LOG_DIR" ]]; then
  echo "No logs found for service '${SERVICE_NAME}'."
  echo "Log directory: ${LOG_DIR}"
  [[ "$BACKEND" == "systemd" ]] && echo "Try: $0 ${SERVICE_NAME} --journald"
  exit 1
fi

echo "=== stdout (${LOG_DIR}/stdout.log) ==="
if [[ "$FOLLOW" == "true" ]]; then
  tail -n "$LINES" -f "$LOG_DIR/stdout.log" 2>/dev/null &
  STDOUT_PID=$!
  echo ""
  echo "=== stderr (${LOG_DIR}/stderr.log) ==="
  tail -n "$LINES" -f "$LOG_DIR/stderr.log" 2>/dev/null
  kill $STDOUT_PID 2>/dev/null || true
else
  tail -n "$LINES" "$LOG_DIR/stdout.log" 2>/dev/null || echo "  (empty)"
  echo ""
  echo "=== stderr (${LOG_DIR}/stderr.log) ==="
  tail -n "$LINES" "$LOG_DIR/stderr.log" 2>/dev/null || echo "  (empty)"
fi
