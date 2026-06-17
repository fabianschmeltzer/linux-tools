#!/usr/bin/env bash
set -Eeuo pipefail

readonly SAFE_PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
export PATH="$SAFE_PATH"

APP_NAME="linux-toolbox"
GITHUB_REPO="${LINUX_TOOLBOX_REPO:-fabianschmeltzer/linux-tools}"
GITHUB_REF="${LINUX_TOOLBOX_REF:-main}"

# Installation immer systemweit
INSTALL_DIR="/usr/local/bin"

SCRIPT_NAME="linux-toolbox.sh"
TARGET_NAME="linux-toolbox"
RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_REF/$SCRIPT_NAME"

TMP_FILE=""

log() {
  printf '[%s installer] %s\n' "$APP_NAME" "$*"
}

die() {
  printf '[%s installer] ERROR: %s\n' "$APP_NAME" "$*" >&2
  exit 1
}

# ----------------------------------------------------------
# Root-Check
# ----------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  die "Dieses Installationsscript muss als root ausgeführt werden (sudo oder root Shell)."
fi

download_url() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    die "Weder curl noch wget gefunden. Bitte eines davon installieren."
  fi
}

ensure_install_dir() {
  mkdir -p "$INSTALL_DIR"
}

install_toolbox() {
  local target

  ensure_install_dir

  TMP_FILE="$(mktemp)"
  target="$INSTALL_DIR/$TARGET_NAME"

  trap 'rm -f "${TMP_FILE:-}"' EXIT

  download_url "$RAW_URL" > "$TMP_FILE"

  chmod 0755 "$TMP_FILE"
  install -m 0755 "$TMP_FILE" "$target"

  log "Installiert: $target"
  log "Quelle: $RAW_URL"

  # ----------------------------------------------------------
  # Bash Completion installieren
  # ----------------------------------------------------------
  local completion_dir

  if [[ -d /etc/bash_completion.d ]]; then
    completion_dir="/etc/bash_completion.d"
  elif [[ -d /usr/local/etc/bash_completion.d ]]; then
    completion_dir="/usr/local/etc/bash_completion.d"
  else
    completion_dir="/usr/local/share/bash-completion/completions"
    mkdir -p "$completion_dir"
  fi

  local completion_url="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_REF/linux-toolbox.completion.bash"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$completion_url" | install -m 0644 /dev/stdin "$completion_dir/linux-toolbox" 2>/dev/null || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$completion_url" | install -m 0644 /dev/stdin "$completion_dir/linux-toolbox" 2>/dev/null || true
  fi

  log "Bash-Completion installiert: $completion_dir/linux-toolbox"

  # ----------------------------------------------------------
  # PATH-Prüfung
  # ----------------------------------------------------------
  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      ;;
    *)
      log "WARNUNG: $INSTALL_DIR befindet sich nicht im PATH."
      ;;
  esac

  log "Starte die Anwendung mit: linux-toolbox"
}

install_toolbox