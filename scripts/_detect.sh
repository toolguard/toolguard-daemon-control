# _detect.sh — Shared OS/backend detection for toolguard scripts
# Source this file; do not execute directly.
# Sets: BACKEND (launchd|systemd), and path variables per backend.

detect_backend() {
  case "$(uname -s)" in
    Darwin)
      BACKEND="launchd"
      ;;
    Linux)
      BACKEND="systemd"
      ;;
    *)
      echo "Error: Unsupported OS '$(uname -s)'. Only macOS and Linux are supported."
      exit 1
      ;;
  esac
}

# Set paths based on backend and service name
# Usage: set_paths <service-name>
set_paths() {
  local name="$1"
  LABEL="ai.toolguard.${name}"

  if [[ "$BACKEND" == "launchd" ]]; then
    PLIST_DIR="$HOME/Library/LaunchAgents"
    PLIST_PATH="${PLIST_DIR}/${LABEL}.plist"
    LOG_DIR="$HOME/Library/Logs/toolguard/${name}"
  else
    UNIT_DIR="$HOME/.config/systemd/user"
    UNIT_PATH="${UNIT_DIR}/${LABEL}.service"
    LOG_DIR="$HOME/.local/share/toolguard/${name}"
  fi
}

detect_backend
