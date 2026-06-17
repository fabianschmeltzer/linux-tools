#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="linux-toolbox"
VERSION="0.1.0"
INSTALL_DIR="${LINUX_TOOLBOX_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_REPO="fabianschmeltzer/linux-tools"
RELEASE_API_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO"
SCRIPT_NAME="linux-toolbox.sh"

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

normalize_version() {
  local version="${1#v}"
  version="${version#V}"
  printf '%s\n' "$version"
}

is_semver() {
  [[ "$1" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]
}

version_gt() {
  local left right
  left="$(normalize_version "$1")"
  right="$(normalize_version "$2")"

  is_semver "$left" || die "Ungültige Version: $1"
  is_semver "$right" || die "Ungültige Version: $2"

  local left_major=0 left_minor=0 left_patch=0
  local right_major=0 right_minor=0 right_patch=0
  IFS=. read -r left_major left_minor left_patch <<<"$left"
  IFS=. read -r right_major right_minor right_patch <<<"$right"
  left_minor="${left_minor:-0}"
  left_patch="${left_patch:-0}"
  right_minor="${right_minor:-0}"
  right_patch="${right_patch:-0}"

  (( left_major > right_major )) && return 0
  (( left_major < right_major )) && return 1
  (( left_minor > right_minor )) && return 0
  (( left_minor < right_minor )) && return 1
  (( left_patch > right_patch ))
}

extract_release_tag() {
  local json="$1"
  sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$json" | head -n 1
}

extract_script_version() {
  local script_body="$1"
  sed -n 's/^VERSION="\([^"]*\)".*/\1/p' <<<"$script_body" | head -n 1
}

load_remote_update() {
  local release_json release_tag release_version release_url release_body
  local main_url main_body main_version

  release_json="$(download_url "$RELEASE_API_URL" 2>/dev/null || true)"
  release_tag="$(extract_release_tag "$release_json")"

  if [[ -n "$release_tag" ]]; then
    release_version="$(normalize_version "$release_tag")"
    if is_semver "$release_version"; then
      release_url="$RAW_BASE_URL/$release_tag/$SCRIPT_NAME"
      release_body="$(download_url "$release_url" 2>/dev/null || true)"
      if [[ -n "$release_body" ]]; then
        printf '%s\n%s\n%s\n' "$release_version" "$release_url" "$release_body"
        return 0
      fi
      warn "Release $release_tag gefunden, aber $SCRIPT_NAME konnte daraus nicht geladen werden. Nutze Fallback main."
    else
      warn "Release-Tag $release_tag ist keine numerische SemVer-Version. Nutze Fallback main."
    fi
  fi

  main_url="$RAW_BASE_URL/main/$SCRIPT_NAME"
  main_body="$(download_url "$main_url")"
  main_version="$(extract_script_version "$main_body")"
  [[ -n "$main_version" ]] || die "Konnte VERSION aus $main_url nicht lesen."
  is_semver "$(normalize_version "$main_version")" || die "Remote-Version ist ungültig: $main_version"

  printf '%s\n%s\n%s\n' "$(normalize_version "$main_version")" "$main_url" "$main_body"
}

check_update() {
  local remote_data remote_version remote_url

  remote_data="$(load_remote_update)"
  remote_version="$(sed -n '1p' <<<"$remote_data")"
  remote_url="$(sed -n '2p' <<<"$remote_data")"

  if version_gt "$remote_version" "$VERSION"; then
    log "Update verfügbar: $VERSION -> $remote_version"
    log "Quelle: $remote_url"
    return 0
  fi

  log "Aktuell: $VERSION"
  log "Geprüfte Quelle: $remote_url"
  return 1
}

self_update() {
  local remote_data remote_version remote_url remote_body target tmp_file target_dir

  remote_data="$(load_remote_update)"
  remote_version="$(sed -n '1p' <<<"$remote_data")"
  remote_url="$(sed -n '2p' <<<"$remote_data")"
  remote_body="$(sed '1,2d' <<<"$remote_data")"

  if ! version_gt "$remote_version" "$VERSION"; then
    log "Keine Aktualisierung nötig. Lokale Version: $VERSION, Remote-Version: $remote_version"
    return 0
  fi

  target="${LINUX_TOOLBOX_SELF_UPDATE_TARGET:-${BASH_SOURCE[0]}}"
  [[ -n "$target" ]] || die "Konnte Ziel für Self-Update nicht bestimmen."
  target_dir="$(cd -- "$(dirname -- "$target")" && pwd)"
  tmp_file="$(mktemp "$target_dir/.${APP_NAME}.update.XXXXXX")"

  printf '%s\n' "$remote_body" > "$tmp_file"
  chmod 0755 "$tmp_file"
  mv "$tmp_file" "$target"

  log "Aktualisiert: $target"
  log "Version: $VERSION -> $remote_version"
  log "Quelle: $remote_url"
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
  self                 installiert dieses Basisscript als linux-toolbox
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
  ./linux-toolbox.sh list
  ./linux-toolbox.sh install <option>
  ./linux-toolbox.sh install-file <pfad> [zielname]
  ./linux-toolbox.sh version
  ./linux-toolbox.sh check-update
  ./linux-toolbox.sh self-update
  ./linux-toolbox.sh help

Beispiele:
  ./linux-toolbox.sh install self
  ./linux-toolbox.sh install docker-start
  LINUX_TOOLBOX_INSTALL_DIR=/usr/local/bin ./linux-toolbox.sh install all
EOF_USAGE
}

install_option() {
  case "${1:-}" in
    self)
      install_script "$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")" "linux-toolbox"
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
    version)
      printf '%s %s\n' "$APP_NAME" "$VERSION"
      ;;
    check-update)
      check_update
      ;;
    self-update)
      self_update
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
