#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="linux-toolbox"
GITHUB_REPO="${LINUX_TOOLBOX_REPO:-fabianschmeltzer/linux-tools}"
GITHUB_REF="${LINUX_TOOLBOX_REF:-main}"
INSTALL_DIR="${LINUX_TOOLBOX_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="linux-toolbox.sh"
TARGET_NAME="linux-toolbox"
RAW_URL="https://raw.githubusercontent.com/$GITHUB_REPO/$GITHUB_REF/$SCRIPT_NAME"
TMP_FILE=""

log() { printf '[%s installer] %s\n' "$APP_NAME" "$*"; }
die() { printf '[%s installer] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }

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

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      log "Hinweis: $INSTALL_DIR ist nicht in PATH. Fuege es hinzu, um '$TARGET_NAME' direkt aufzurufen."
      log "Beispiel: export PATH=\"$INSTALL_DIR:$PATH\""
      ;;
  esac
}

install_toolbox
