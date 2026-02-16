#!/bin/bash
set -euo pipefail

# install.sh — Install an executable as a persistent user service
# Supports macOS launchd and Linux systemd.
# Usage: install.sh <service-name> <command> [args...] [--workdir <dir>] [--env KEY=VALUE ...]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_detect.sh"

usage() {
  echo "Usage: $0 <service-name> <command> [args...] [--workdir <dir>] [--env KEY=VALUE ...]"
  exit 1
}

[[ $# -lt 2 ]] && usage

SERVICE_NAME="$1"; shift
set_paths "$SERVICE_NAME"
WORKDIR="$HOME"

# Parse command, args, and options
COMMAND=""
ARGS=()
ENV_VARS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir)
      WORKDIR="$2"; shift 2 ;;
    --env)
      ENV_VARS+=("$2"); shift 2 ;;
    *)
      if [[ -z "$COMMAND" ]]; then
        COMMAND="$1"
      else
        ARGS+=("$1")
      fi
      shift ;;
  esac
done

[[ -z "$COMMAND" ]] && usage

# Resolve command to absolute path
if [[ "$COMMAND" != /* ]]; then
  RESOLVED=$(which "$COMMAND" 2>/dev/null || true)
  if [[ -n "$RESOLVED" ]]; then
    COMMAND="$RESOLVED"
  else
    echo "Error: Cannot resolve '$COMMAND' to an absolute path."
    exit 1
  fi
fi

# Expand workdir
WORKDIR=$(eval echo "$WORKDIR")

install_launchd() {
  mkdir -p "$PLIST_DIR" "$LOG_DIR"

  if launchctl list "$LABEL" &>/dev/null; then
    echo "Unloading existing service ${LABEL}..."
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
  fi

  PROGRAM_ARGS="    <array>
      <string>${COMMAND}</string>"
  for arg in "${ARGS[@]}"; do
    PROGRAM_ARGS+="
      <string>${arg}</string>"
  done
  PROGRAM_ARGS+="
    </array>"

  ENV_SECTION=""
  if [[ ${#ENV_VARS[@]} -gt 0 ]]; then
    ENV_SECTION="    <key>EnvironmentVariables</key>
    <dict>"
    for env_pair in "${ENV_VARS[@]}"; do
      KEY="${env_pair%%=*}"
      VALUE="${env_pair#*=}"
      ENV_SECTION+="
      <key>${KEY}</key>
      <string>${VALUE}</string>"
    done
    ENV_SECTION+="
    </dict>"
  fi

  cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
${PROGRAM_ARGS}
    <key>WorkingDirectory</key>
    <string>${WORKDIR}</string>
    <key>StandardOutPath</key>
    <string>${LOG_DIR}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/stderr.log</string>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
${ENV_SECTION}
</dict>
</plist>
EOF

  launchctl load "$PLIST_PATH"

  echo "Service '${SERVICE_NAME}' installed and started (launchd)."
  echo "  Label:  ${LABEL}"
  echo "  Plist:  ${PLIST_PATH}"
  echo "  Logs:   ${LOG_DIR}/"
  echo "  Status: $(launchctl list "$LABEL" 2>/dev/null | head -1 || echo 'unknown')"
}

install_systemd() {
  mkdir -p "$UNIT_DIR" "$LOG_DIR"

  EXEC_START="$COMMAND"
  for arg in "${ARGS[@]}"; do
    EXEC_START+=" $arg"
  done

  ENV_LINES=""
  for env_pair in "${ENV_VARS[@]}"; do
    ENV_LINES+="Environment=${env_pair}"$'\n'
  done

  cat > "$UNIT_PATH" <<EOF
[Unit]
Description=Toolguard service: ${SERVICE_NAME}

[Service]
Type=simple
ExecStart=${EXEC_START}
WorkingDirectory=${WORKDIR}
Restart=always
RestartSec=5
StandardOutput=append:${LOG_DIR}/stdout.log
StandardError=append:${LOG_DIR}/stderr.log
${ENV_LINES}
[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "$LABEL"

  echo "Service '${SERVICE_NAME}' installed and started (systemd)."
  echo "  Label:  ${LABEL}"
  echo "  Unit:   ${UNIT_PATH}"
  echo "  Logs:   ${LOG_DIR}/ (also: journalctl --user -u ${LABEL})"
  echo "  Status: $(systemctl --user is-active "$LABEL" 2>/dev/null || echo 'unknown')"
}

if [[ "$BACKEND" == "launchd" ]]; then
  install_launchd
else
  install_systemd
fi
