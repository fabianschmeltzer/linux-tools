#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="linux-tools"
INSTALL_DIR="${LINUX_TOOLS_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[%s] %s\n' "$APP_NAME" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$APP_NAME" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }

ensure_install_dir() {
  mkdir -p "$INSTALL_DIR"
}

install_script() {
  local source_file="$1"
  local target_name="${2:-$(basename "$source_file")}"

  [[ -f "$source_file" ]] || die "Script nicht gefunden: $source_file"
  ensure_install_dir
  install -m 0755 "$source_file" "$INSTALL_DIR/$target_name"
  log "Installiert: $INSTALL_DIR/$target_name"
}

install_from_template() {
  local name="$1"
  local target="$INSTALL_DIR/$name"

  ensure_install_dir
  if [[ -e "$target" ]]; then
    warn "Überspringe vorhandenes Script: $target"
    return 0
  fi

  case "$name" in
    docker-start)
      cat > "$target" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
compose_file="${1:-docker-compose.yml}"
docker compose -f "$compose_file" up -d
SCRIPT
      ;;
    docker-stop)
      cat > "$target" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
compose_file="${1:-docker-compose.yml}"
docker compose -f "$compose_file" down
SCRIPT
      ;;
    maintenance-upgrade)
      cat > "$target" <<'SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
SCRIPT
      ;;
    *)
      die "Unbekanntes Template: $name"
      ;;
  esac
  chmod 0755 "$target"
  log "Template installiert: $target"
}

list_available() {
  cat <<EOF_LIST
Verfügbare Installationsoptionen:
  self                 installiert dieses Basisscript als linux-tools
  docker-start         erstellt ein Docker-Compose-Startscript
  docker-stop          erstellt ein Docker-Compose-Stopscript
  maintenance-upgrade  erstellt ein einfaches APT-Wartungs-/Upgrade-Script
  all                  installiert alle oben genannten Scripts

Installationsziel: $INSTALL_DIR
EOF_LIST
}

usage() {
  cat <<EOF_USAGE
$APP_NAME - Baseline und Installer für persönliche Linux-Hilfsscripts

Verwendung:
  ./linux-tools.sh list
  ./linux-tools.sh install <option>
  ./linux-tools.sh install-file <pfad> [zielname]
  ./linux-tools.sh help

Beispiele:
  ./linux-tools.sh install self
  ./linux-tools.sh install docker-start
  LINUX_TOOLS_INSTALL_DIR=/usr/local/bin ./linux-tools.sh install all
EOF_USAGE
}

install_option() {
  case "${1:-}" in
    self)
      install_script "$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")" "linux-tools"
      ;;
    docker-start|docker-stop|maintenance-upgrade)
      install_from_template "$1"
      ;;
    all)
      install_option self
      install_option docker-start
      install_option docker-stop
      install_option maintenance-upgrade
      ;;
    "")
      die "Bitte eine Installationsoption angeben. Nutze: $0 list"
      ;;
    *)
      die "Unbekannte Installationsoption: $1"
      ;;
  esac
}

main() {
  local command="${1:-help}"
  shift || true

  case "$command" in
    list)
      list_available
      ;;
    install)
      install_option "${1:-}"
      ;;
    install-file)
      install_script "${1:-}" "${2:-}"
      ;;
    help|-h|--help)
      usage
      ;;
    *)
      usage
      die "Unbekannter Befehl: $command"
      ;;
  esac
}

main "$@"
