#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="linux-toolbox"
VERSION="0.1.3"
INSTALL_DIR="${LINUX_TOOLBOX_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
GITHUB_REPO="fabianschmeltzer/linux-tools"
RELEASE_API_URL="https://api.github.com/repos/$GITHUB_REPO/releases/latest"
RAW_BASE_URL="https://raw.githubusercontent.com/$GITHUB_REPO"
SCRIPT_NAME="linux-toolbox.sh"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$XDG_CONFIG_HOME/linux-toolbox"
CONFIG_FILE="$CONFIG_DIR/config"
LANGUAGE="${LINUX_TOOLBOX_LANGUAGE:-${LANGUAGE:-${LANG:-}}}"
LANGUAGE="$(printf '%s' "$LANGUAGE" | tr '[:upper:]' '[:lower:]' | cut -c1-2)"
LANGUAGE="${LANGUAGE:-en}"

log() { printf '[%s] %s\n' "$APP_NAME" "$*"; }
warn() { printf '[%s] WARN: %s\n' "$APP_NAME" "$*" >&2; }
die() { printf '[%s] ERROR: %s\n' "$APP_NAME" "$*" >&2; exit 1; }

ensure_install_dir() {
  mkdir -p "$INSTALL_DIR"
}

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    while IFS='=' read -r key value; do
      case "$key" in
        install_dir) INSTALL_DIR="$value" ;;
        language) LANGUAGE="$value" ;;
      esac
    done < "$CONFIG_FILE"
  fi
}

save_config() {
  ensure_config_dir
  cat > "$CONFIG_FILE" <<EOF
install_dir=$INSTALL_DIR
language=$LANGUAGE
EOF
}

install_script() {
  local source_file="$1"
  local target_name="${2:-$(basename "$source_file")}"

  [[ -f "$source_file" ]] || die "${MSG_INSTALL_ERR//%s/$source_file}"
  ensure_install_dir
  install -m 0755 "$source_file" "$INSTALL_DIR/$target_name"
  log "${MSG_INSTALLED//%s/$INSTALL_DIR/$target_name}"
}

install_script_url() {
  local url="$1"
  local target_name="$2"
  local tmp_file

  ensure_install_dir
  tmp_file="$(mktemp)"
  trap 'rm -f "${tmp_file:-}"' EXIT
  download_url "$url" > "$tmp_file"
  chmod 0755 "$tmp_file"
  install -m 0755 "$tmp_file" "$INSTALL_DIR/$target_name"
  log "${MSG_INSTALLED//%s/$INSTALL_DIR/$target_name}"
}

download_url_safe() {
  local url="$1"
  set +e
  download_url "$url"
  local rc=$?
  set -e
  return $rc
}

set_messages() {
  if [[ "$LANGUAGE" == "de" ]]; then
    MSG_NEED_CURL_WGET="Weder curl noch wget gefunden. Bitte eines davon installieren."
    MSG_UPDATE_AVAILABLE="Update verfügbar: %s -> %s"
    MSG_SOURCE_IS="Quelle: %s"
    MSG_CURRENT="Aktuell: %s"
    MSG_CHECKED_SOURCE="Geprüfte Quelle: %s"
    MSG_NO_UPDATE="Keine Aktualisierung nötig. Lokale Version: %s, Remote-Version: %s"
    MSG_UPDATED="Aktualisiert: %s"
    MSG_VERSION="Version %s"
    MSG_INSTALL_ERR="Script nicht gefunden: %s"
    MSG_UNKNOWN_COMMAND="Unbekannter Befehl: %s"
    MSG_INVALID_OPTION="Unbekannte Installationsoption: %s"
    MSG_SELECT_CATEGORY="Wähle eine Kategorie:"
    MSG_SELECT_SCRIPT="Wähle ein Script zum Installieren:"
    MSG_SETTINGS="Einstellungen"
    MSG_LANGUAGE="Sprache"
    MSG_INSTALL_DIR="Standard-Installationsort"
    MSG_CONFIG_SAVED="Einstellungen gespeichert."
    MSG_MENU_TITLE="linux-toolbox UI"
    MSG_NO_SCRIPT="Keine gültige Auswahl."
    MSG_INSTALLED="Installiert: %s"
    MSG_TEMPLATE_INSTALLED="Template installiert: %s"
    MSG_SKIP_EXISTING="Überspringe vorhandenes Script: %s"
    MSG_SELECT_OPTION="Wähle eine Option:"
    MSG_BACK="Zurück"
    MSG_SAVE_EXIT="Speichern und beenden"
    MSG_ENTER_LANGUAGE="Sprache eingeben (de/en):"
    MSG_ENTER_INSTALL_DIR="Installationsverzeichnis eingeben:"
    MSG_CURRENT_VALUE="Aktueller Wert: %s"
    MSG_MENU_HEADER="%s"
    MSG_LIST_TITLE="Verfügbare Installationsoptionen:"
    MSG_OPTION_SELF="self                 installiert dieses Basisscript als linux-toolbox"
    MSG_OPTION_DOCKER_START="docker-start         erstellt ein Docker-Compose-Startscript"
    MSG_OPTION_DOCKER_STOP="docker-stop          erstellt ein Docker-Compose-Stopscript"
    MSG_OPTION_MAINTENANCE="maintenance-upgrade  erstellt ein APT-Wartungs-/Upgrade-Script"
    MSG_OPTION_BCACHE="bcache-monitor       installiert das Linux-Bcache-Monitor-Script"
    MSG_OPTION_ALL="all                  installiert alle oben genannten Scripts"
    MSG_USAGE_TITLE="$APP_NAME - Baseline und Installer für persönliche Linux-Hilfsscripts"
    MSG_USAGE_USAGE="Verwendung:"
    MSG_USAGE_examples="Beispiele:"
    MSG_USAGE_COMMANDS="  linux-toolbox list\n  linux-toolbox install <option>\n  linux-toolbox install-file <pfad> [zielname]\n  linux-toolbox ui\n  linux-toolbox settings\n  linux-toolbox version\n  linux-toolbox check-update\n  linux-toolbox self-update\n  linux-toolbox help"
    MSG_SETTINGS_TITLE="Einstellungen"
    MSG_MONITORING="Monitoring"
    MSG_DOCKER="Docker"
    MSG_MAINTENANCE="Maintenance"
  else
    MSG_NEED_CURL_WGET="Neither curl nor wget found. Please install one of them."
    MSG_UPDATE_AVAILABLE="Update available: %s -> %s"
    MSG_SOURCE_IS="Source: %s"
    MSG_CURRENT="Current: %s"
    MSG_CHECKED_SOURCE="Checked source: %s"
    MSG_NO_UPDATE="No update needed. Local version: %s, remote version: %s"
    MSG_UPDATED="Updated: %s"
    MSG_VERSION="Version %s"
    MSG_INSTALL_ERR="Script not found: %s"
    MSG_UNKNOWN_COMMAND="Unknown command: %s"
    MSG_INVALID_OPTION="Unknown installation option: %s"
    MSG_SELECT_CATEGORY="Choose a category:"
    MSG_SELECT_SCRIPT="Choose a script to install:"
    MSG_SETTINGS="Settings"
    MSG_LANGUAGE="Language"
    MSG_INSTALL_DIR="Default install directory"
    MSG_CONFIG_SAVED="Settings saved."
    MSG_MENU_TITLE="linux-toolbox UI"
    MSG_NO_SCRIPT="No valid selection."
    MSG_INSTALLED="Installed: %s"
    MSG_TEMPLATE_INSTALLED="Template installed: %s"
    MSG_SKIP_EXISTING="Skipping existing script: %s"
    MSG_SELECT_OPTION="Choose an option:"
    MSG_BACK="Back"
    MSG_SAVE_EXIT="Save and exit"
    MSG_ENTER_LANGUAGE="Enter language (de/en):"
    MSG_ENTER_INSTALL_DIR="Enter install directory:"
    MSG_CURRENT_VALUE="Current value: %s"
    MSG_MENU_HEADER="%s"
    MSG_LIST_TITLE="Available installation options:"
    MSG_OPTION_SELF="self                 installs this base script as linux-toolbox"
    MSG_OPTION_DOCKER_START="docker-start         creates a Docker Compose start script"
    MSG_OPTION_DOCKER_STOP="docker-stop          creates a Docker Compose stop script"
    MSG_OPTION_MAINTENANCE="maintenance-upgrade  creates an APT maintenance/upgrade script"
    MSG_OPTION_BCACHE="bcache-monitor       installs the Linux Bcache Monitor script"
    MSG_OPTION_ALL="all                  installs all scripts listed above"
    MSG_USAGE_TITLE="$APP_NAME - Baseline and installer for personal Linux helper scripts"
    MSG_USAGE_USAGE="Usage:"
    MSG_USAGE_examples="Examples:"
    MSG_USAGE_COMMANDS="  linux-toolbox list\n  linux-toolbox install <option>\n  linux-toolbox install-file <path> [target-name]\n  linux-toolbox ui\n  linux-toolbox settings\n  linux-toolbox version\n  linux-toolbox check-update\n  linux-toolbox self-update\n  linux-toolbox help"
    MSG_SETTINGS_TITLE="Settings"
    MSG_MONITORING="Monitoring"
    MSG_DOCKER="Docker"
    MSG_MAINTENANCE="Maintenance"
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

  release_json="$(download_url_safe "$RELEASE_API_URL")"
  release_tag="$(extract_release_tag "$release_json")"

  if [[ -n "$release_tag" ]]; then
    release_version="$(normalize_version "$release_tag")"
    if is_semver "$release_version"; then
      release_url="$RAW_BASE_URL/$release_tag/$SCRIPT_NAME"
      release_body="$(download_url_safe "$release_url")"
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
  main_body="$(download_url_safe "$main_url")"
  [[ -n "$main_body" ]] || die "Konnte $SCRIPT_NAME von $main_url nicht laden."
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
    log "$(printf "$MSG_UPDATE_AVAILABLE" "$VERSION" "$remote_version")"
    log "$(printf "$MSG_SOURCE_IS" "$remote_url")"
    return 0
  fi

  log "$(printf "$MSG_CURRENT" "$VERSION")"
  log "$(printf "$MSG_CHECKED_SOURCE" "$remote_url")"
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
  log "${MSG_TEMPLATE_INSTALLED//%s/$target}"
}

install_bcache_monitor() {
  local target_name="bcache-monitor"
  local url="https://raw.githubusercontent.com/fabianschmeltzer/Linux-Bcache-Monitor/main/bcache-monitor"
  install_script_url "$url" "$target_name"
}

show_header() {
  clear
  printf '\n'
  printf '  ╔══════════════════════════════════════════╗\n'
  printf '  ║   linux-toolbox v%s\n' "$VERSION"
  printf '  ║   %s\n' "$1"
  printf '  ╚══════════════════════════════════════════╝\n'
  printf '\n'
}

show_menu_item() {
  local num=$1 label=$2 desc=$3
  printf '  %2d) %-20s  %s\n' "$num" "$label" "$desc"
}

show_separator() {
  printf '  ──────────────────────────────────────────\n'
}

show_monitor_menu() {
  show_header "📊 Monitoring Scripts"
  printf '  These scripts help monitor your system:\n\n'
  show_menu_item "1" "bcache-monitor" "Monitor Linux bcache devices (SSD cache + HDD)"
  show_menu_item "0" "← Back" "Return to main menu"
  show_separator
  read -rp '  Choose option (0-1): ' choice
  case "$choice" in
    1)
      printf '\n  ⏳ Installing bcache-monitor...\n'
      install_bcache_monitor
      printf '\n  ✓ Installation complete!\n'
      read -rp '  Press Enter to continue...'
      ;;
    0) ;;
    *) printf '  ✗ Invalid choice.\n'; read -rp '  Press Enter...'; show_monitor_menu ;;
  esac
}

show_docker_menu() {
  show_header "🐳 Docker Scripts"
  printf '  Docker Compose management scripts:\n\n'
  show_menu_item "1" "docker-start" "Start Docker Compose project"
  show_menu_item "2" "docker-stop" "Stop Docker Compose project"
  show_menu_item "0" "← Back" "Return to main menu"
  show_separator
  read -rp '  Choose option (0-2): ' choice
  case "$choice" in
    1)
      printf '\n  ⏳ Installing docker-start...\n'
      install_from_template "docker-start"
      printf '\n  ✓ Installation complete!\n'
      read -rp '  Press Enter to continue...'
      ;;
    2)
      printf '\n  ⏳ Installing docker-stop...\n'
      install_from_template "docker-stop"
      printf '\n  ✓ Installation complete!\n'
      read -rp '  Press Enter to continue...'
      ;;
    0) ;;
    *) printf '  ✗ Invalid choice.\n'; read -rp '  Press Enter...'; show_docker_menu ;;
  esac
}

show_maintenance_menu() {
  show_header "🔧 System Maintenance"
  printf '  System administration and maintenance:\n\n'
  show_menu_item "1" "maintenance-upgrade" "Update system packages"
  show_menu_item "0" "← Back" "Return to main menu"
  show_separator
  read -rp '  Choose option (0-1): ' choice
  case "$choice" in
    1)
      printf '\n  ⏳ Installing maintenance-upgrade...\n'
      install_from_template "maintenance-upgrade"
      printf '\n  ✓ Installation complete!\n'
      read -rp '  Press Enter to continue...'
      ;;
    0) ;;
    *) printf '  ✗ Invalid choice.\n'; read -rp '  Press Enter...'; show_maintenance_menu ;;
  esac
}

settings_menu() {
  while true; do
    show_header "⚙️  Settings"
    printf '  Configure linux-toolbox:\n\n'
    show_menu_item "1" "Language" "Current: $LANGUAGE"
    show_menu_item "2" "Install Dir" "Current: $INSTALL_DIR"
    show_menu_item "3" "Save & Exit" "Save changes and return"
    show_menu_item "0" "← Back" "Discard changes"
    show_separator
    read -rp '  Choose option (0-3): ' choice
    case "$choice" in
      1)
        printf '\n  Enter language code (de/en): '
        read -r new_lang
        if [[ "$new_lang" == "de" || "$new_lang" == "en" ]]; then
          LANGUAGE="$new_lang"
          set_messages
          printf '  ✓ Language changed to %s\n' "$new_lang"
        else
          printf '  ✗ Invalid language.\n'
        fi
        read -rp '  Press Enter...'
        ;;
      2)
        printf '\n  Enter install directory: '
        read -r new_dir
        if [[ -d "$new_dir" || -z "$new_dir" ]]; then
          [[ -n "$new_dir" ]] && INSTALL_DIR="$new_dir"
          printf '  ✓ Install directory updated.\n'
        else
          printf '  ✗ Directory does not exist.\n'
        fi
        read -rp '  Press Enter...'
        ;;
      3)
        save_config
        printf '\n  ✓ Settings saved.\n'
        read -rp '  Press Enter...'
        return 0
        ;;
      0)
        return 0
        ;;
      *) printf '  ✗ Invalid choice.\n'; read -rp '  Press Enter...';;
    esac
  done
}

ui_menu() {
  while true; do
    show_header "Main Menu"
    printf '  Select a category to explore:\n\n'
    show_menu_item "1" "📊 Monitoring" "System monitoring tools"
    show_menu_item "2" "🐳 Docker" "Docker Compose utilities"
    show_menu_item "3" "🔧 Maintenance" "System administration"
    show_menu_item "4" "⚙️  Settings" "Configure linux-toolbox"
    show_menu_item "0" "✕ Exit" "Close linux-toolbox"
    show_separator
    read -rp '  Choose option (0-4): ' choice
    case "$choice" in
      1) show_monitor_menu ;;
      2) show_docker_menu ;;
      3) show_maintenance_menu ;;
      4) settings_menu ;;
      0)
        printf '\n  👋 Goodbye!\n\n'
        return 0
        ;;
      *) printf '  ✗ Invalid choice.\n'; read -rp '  Press Enter...';;
    esac
  done
}

list_available() {
  cat <<EOF

  ╔════════════════════════════════════════════════════════════════╗
  ║           Available Installation Options                       ║
  ╚════════════════════════════════════════════════════════════════╝

  self                    Install linux-toolbox as system command
  docker-start            Docker Compose project starter script
  docker-stop             Docker Compose project stopper script
  maintenance-upgrade     System package update and maintenance
  bcache-monitor          Linux bcache device monitoring tool
  all                     Install all scripts above

  ────────────────────────────────────────────────────────────────
  Install destination:    $INSTALL_DIR

EOF
}

usage() {
  cat <<'EOF'

  ╔════════════════════════════════════════════════════════════════╗
  ║  linux-toolbox v0.1.3                                          ║
  ║  Baseline and installer for personal Linux helper scripts      ║
  ╚════════════════════════════════════════════════════════════════╝

  USAGE:
    linux-toolbox COMMAND [OPTIONS]

  COMMANDS:
    list                Show available scripts to install
    install <option>    Install a script or template
    install-file <path> Install custom script from file
    ui                  Open interactive menu
    settings            Configure linux-toolbox
    version             Show version information
    check-update        Check for updates
    self-update         Update linux-toolbox
    help                Show this help message

  EXAMPLES:
    linux-toolbox list
    linux-toolbox install docker-start
    linux-toolbox install-file ./my-script.sh my-script
    linux-toolbox ui
    linux-toolbox settings
    LINUX_TOOLBOX_INSTALL_DIR=/usr/local/bin linux-toolbox install all

  For more information, visit: https://github.com/fabianschmeltzer/linux-tools

EOF
}

install_option() {
  case "${1:-}" in
    self)
      install_script "$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")" "linux-toolbox"
      ;;
    docker-start|docker-stop|maintenance-upgrade)
      install_from_template "$1"
      ;;
    bcache-monitor)
      install_bcache_monitor
      ;;
    all)
      install_option self
      install_option docker-start
      install_option docker-stop
      install_option maintenance-upgrade
      install_option bcache-monitor
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
  load_config
  set_messages

  local command="${1:-help}"
  shift || true

  case "$command" in
    version)
      printf '%s %s\n' "$APP_NAME" "$VERSION"
      return 0
      ;;
    list)
      list_available
      ;;
    install)
      install_option "${1:-}"
      ;;
    install-file)
      install_script "${1:-}" "${2:-}"
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
    ui)
      ui_menu
      ;;
    settings)
      settings_menu
      ;;
    *)
      usage
      die "Unbekannter Befehl: $command"
      ;;
  esac
}

main "$@"
