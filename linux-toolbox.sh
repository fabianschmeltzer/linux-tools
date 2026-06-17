#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="linux-toolbox"
VERSION="0.1.8"
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
download_url() {
  local url="$1"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url"
  else
    die "$MSG_NEED_CURL_WGET"
  fi
}

# ===== VALIDATION FUNCTIONS =====
validate_file_exists() {
  local file="$1"
  [[ -f "$file" ]] || die "File not found: $file"
}

validate_file_readable() {
  local file="$1"
  [[ -r "$file" ]] || die "File not readable: $file"
}

validate_file_writable() {
  local file="$1"
  local dir="$(dirname "$file")"
  if [[ -f "$file" ]]; then
    [[ -w "$file" ]] || die "File not writable: $file"
  else
    [[ -w "$dir" ]] || die "Directory not writable: $dir"
  fi
}

validate_executable() {
  local file="$1"
  [[ -x "$file" ]] || die "File not executable: $file"
}

validate_bash_syntax() {
  local file="$1"
  bash -n "$file" 2>/dev/null || die "Bash syntax error in: $file"
}

validate_checksum_sha256() {
  local file="$1"
  local expected="$2"
  if command -v sha256sum >/dev/null 2>&1; then
    local actual
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [[ "$actual" != "$expected" ]]; then
      die "Checksum mismatch for $file (expected: $expected, got: $actual)"
    fi
    return 0
  fi
  return 1
}

validate_dir_exists() {
  local dir="$1"
  [[ -d "$dir" ]] || die "Directory not found: $dir"
}

validate_installation() {
  local target="$1"
  local name="${2:-}"
  
  # Check if file exists
  [[ -f "$target" ]] || die "Installation failed: file not created ($target)"
  
  # Check if executable
  [[ -x "$target" ]] || die "Installation failed: file not executable ($target)"
  
  # Check if readable
  [[ -r "$target" ]] || die "Installation failed: file not readable ($target)"
  
  # Optional: Check if contains expected content
  if [[ -n "$name" ]]; then
    case "$name" in
      self|linux-toolbox)
        grep -q "VERSION=" "$target" || die "Installation failed: version marker not found ($target)"
        ;;
      docker-start)
        grep -q "docker compose" "$target" || die "Installation failed: docker command not found ($target)"
        ;;
      docker-stop)
        grep -q "docker compose" "$target" || die "Installation failed: docker command not found ($target)"
        ;;
      maintenance-upgrade)
        grep -q "apt" "$target" || die "Installation failed: apt command not found ($target)"
        ;;
    esac
  fi
  
  log "✓ Installation verified: $target"
}

validate_config() {
  local config="$1"
  
  [[ -f "$config" ]] || die "Config not found: $config"
  [[ -r "$config" ]] || die "Config not readable: $config"
  
  # Check config format
  if ! grep -q "^[a-z_]*=" "$config"; then
    die "Config format invalid: $config"
  fi
  
  log "✓ Config verified: $config"
}

validate_download() {
  local url="$1"
  local content="$2"
  
  # Check if content is not empty
  [[ -n "$content" ]] || die "Download failed: empty content from $url"
  
  # Check if content looks valid (basic check)
  [[ "$content" == *"#!/"* ]] || [[ "$content" == *"#!"* ]] || \
  [[ "$content" == *"{"* ]] || [[ "$content" == *"["* ]] || \
  return 0  # Allow if doesn't match patterns (could be other formats)
  
  log "✓ Download verified: $url"
}

ensure_install_dir() {
  mkdir -p "$INSTALL_DIR"
}

ensure_config_dir() {
  mkdir -p "$CONFIG_DIR"
}

load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # Validate config file before reading
    validate_file_readable "$CONFIG_FILE" || return 1
    validate_config "$CONFIG_FILE" || return 1
    
    while IFS='=' read -r key value; do
      # Validate key format (alphanumeric + underscore)
      if [[ "$key" =~ ^[a-z_]+$ ]]; then
        case "$key" in
          install_dir) 
            # Validate directory is writable
            if [[ -d "$value" ]] && [[ -w "$value" ]]; then
              INSTALL_DIR="$value"
            fi
            ;;
          language)
            # Validate language code (2 chars, lowercase)
            if [[ "$value" =~ ^[a-z]{2}$ ]]; then
              LANGUAGE="$value"
            fi
            ;;
        esac
      fi
    done < "$CONFIG_FILE"
  fi
}

save_config() {
  ensure_config_dir
  validate_dir_exists "$CONFIG_DIR"
  validate_file_writable "$CONFIG_FILE"
  
  # Write config
  cat > "$CONFIG_FILE" <<EOF
install_dir=$INSTALL_DIR
language=$LANGUAGE
EOF
  
  # Validate written config
  if validate_config "$CONFIG_FILE"; then
    log "✓ Config saved: $CONFIG_FILE"
  else
    die "Config validation failed after save"
  fi
}

install_script() {
  local source_file="$1"
  local target_name="${2:-$(basename "$source_file")}"
  local target_path="$INSTALL_DIR/$target_name"

  # Validation Phase 1: Source file
  validate_file_exists "$source_file"
  validate_file_readable "$source_file"
  
  # Validation Phase 2: Target directory
  ensure_install_dir
  validate_dir_exists "$INSTALL_DIR"
  validate_file_writable "$target_path"
  
  # Validation Phase 3: Install
  install -m 0755 "$source_file" "$target_path" || die "Installation command failed: $target_path"
  
  # Validation Phase 4: Verify installation
  validate_installation "$target_path" "$target_name"
  
  log "✓ ${MSG_INSTALLED//%s/$target_path}"
}

install_script_url() {
  local url="$1"
  local target_name="$2"
  local tmp_file target_path

  ensure_install_dir
  validate_dir_exists "$INSTALL_DIR"
  
  tmp_file="$(mktemp)" || die "Failed to create temporary file"
  trap 'rm -f "${tmp_file:-}"' EXIT
  
  # Download with validation
  local content
  content="$(download_url "$url")" || die "Download failed: $url"
  validate_download "$url" "$content"
  
  # Write to temp file
  printf '%s\n' "$content" > "$tmp_file" || die "Failed to write to temporary file"
  
  # Validate bash syntax
  validate_bash_syntax "$tmp_file"
  
  # Set executable
  chmod 0755 "$tmp_file" || die "Failed to set executable bit on temporary file"
  
  # Install
  target_path="$INSTALL_DIR/$target_name"
  validate_file_writable "$target_path"
  install -m 0755 "$tmp_file" "$target_path" || die "Installation command failed: $target_path"
  
  # Verify installation
  validate_installation "$target_path" "$target_name"
  
  log "✓ ${MSG_INSTALLED//%s/$target_path}"
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
  local remote_data remote_version remote_url remote_body target tmp_file target_dir backup_file

  # Load remote update with validation
  remote_data="$(load_remote_update)" || die "Failed to load remote update"
  remote_version="$(sed -n '1p' <<<"$remote_data")"
  remote_url="$(sed -n '2p' <<<"$remote_data")"
  remote_body="$(sed '1,2d' <<<"$remote_data")"

  # Validate remote data
  [[ -n "$remote_version" ]] || die "Remote version not found"
  [[ -n "$remote_url" ]] || die "Remote URL not found"
  validate_download "$remote_url" "$remote_body"

  if ! version_gt "$remote_version" "$VERSION"; then
    log "Keine Aktualisierung nötig. Lokale Version: $VERSION, Remote-Version: $remote_version"
    return 0
  fi

  target="${LINUX_TOOLBOX_SELF_UPDATE_TARGET:-${BASH_SOURCE[0]}}"
  [[ -n "$target" ]] || die "Konnte Ziel für Self-Update nicht bestimmen."
  
  # Validate target
  validate_file_exists "$target"
  validate_file_readable "$target"
  validate_file_writable "$target"
  
  target_dir="$(cd -- "$(dirname -- "$target")" && pwd)"
  validate_dir_exists "$target_dir"
  
  # Create backup
  backup_file="${target}.backup"
  cp "$target" "$backup_file" || die "Failed to create backup: $backup_file"
  trap "rm -f '$backup_file'" EXIT

  # Create temp file
  tmp_file="$(mktemp "$target_dir/.${APP_NAME}.update.XXXXXX")" || die "Failed to create temp file"
  trap 'rm -f "$tmp_file" "$backup_file"' EXIT

  # Write update
  printf '%s\n' "$remote_body" > "$tmp_file" || die "Failed to write update to temp file"

  # Validate new version
  validate_bash_syntax "$tmp_file"
  
  # Set executable
  chmod 0755 "$tmp_file" || die "Failed to set executable bit"

  # Move to target
  mv "$tmp_file" "$target" || {
    cp "$backup_file" "$target"
    die "Failed to update: $target"
  }

  # Verify update
  validate_installation "$target" "linux-toolbox"

  # Cleanup backup on success
  rm -f "$backup_file"

  log "✓ Aktualisiert: $target"
  log "✓ Version: $VERSION -> $remote_version"
  log "✓ Quelle: $remote_url"
}

install_from_template() {
  local name="$1"
  local target="$INSTALL_DIR/$name"

  ensure_install_dir
  validate_dir_exists "$INSTALL_DIR"
  
  if [[ -e "$target" ]]; then
    warn "Überspringe vorhandenes Script: $target"
    return 0
  fi

  local template_content
  case "$name" in
    docker-start)
      template_content='#!/usr/bin/env bash
set -Eeuo pipefail
compose_file="${1:-docker-compose.yml}"
docker compose -f "$compose_file" up -d'
      ;;
    docker-stop)
      template_content='#!/usr/bin/env bash
set -Eeuo pipefail
compose_file="${1:-docker-compose.yml}"
docker compose -f "$compose_file" down'
      ;;
    maintenance-upgrade)
      template_content='#!/usr/bin/env bash
set -Eeuo pipefail
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y'
      ;;
    *)
      die "Unbekanntes Template: $name"
      ;;
  esac
  
  # Write template with validation
  printf '%s\n' "$template_content" > "$target" || die "Failed to write template: $target"
  
  # Validate bash syntax
  validate_bash_syntax "$target"
  
  # Set executable
  chmod 0755 "$target" || die "Failed to set executable bit: $target"
  
  # Verify installation
  validate_installation "$target" "$name"
  
  log "✓ ${MSG_TEMPLATE_INSTALLED//%s/$target}"
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
  ║  linux-toolbox v%s\n' "$VERSION"                                          ║
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

auto_update_check() {
  local skip_update="${LINUX_TOOLBOX_SKIP_UPDATE:-}"
  
  # Skip if explicitly disabled
  if [[ "$skip_update" == "1" ]]; then
    return 0
  fi
  
  # Skip if running from source directory (development mode)
  if [[ "${BASH_SOURCE[0]}" == "$SCRIPT_DIR"* ]]; then
    return 0
  fi
  
  # Check update silently in background without blocking
  (
    set +e
    
    # Load config for language
    load_config 2>/dev/null || true
    set_messages 2>/dev/null || true
    
    local remote_data
    remote_data="$(load_remote_update 2>/dev/null)" || return 0
    
    local remote_version
    remote_version="$(sed -n '1p' <<<"$remote_data")"
    
    # Check if update is available
    if ! version_gt "$remote_version" "$VERSION"; then
      return 0
    fi
    
    # Update is available - proceed with auto-update
    local remote_url remote_body target tmp_file
    remote_url="$(sed -n '2p' <<<"$remote_data")"
    remote_body="$(sed '1,2d' <<<"$remote_data")"
    
    # Find the installed location
    local script_location
    script_location="$(command -v linux-toolbox 2>/dev/null)" || return 0
    
    # Validate update content
    if ! validate_download "$remote_url" "$remote_body"; then
      return 0
    fi
    
    # Create temporary file
    tmp_file="$(mktemp)" || return 0
    trap 'rm -f "$tmp_file"' EXIT
    
    # Write and validate
    printf '%s\n' "$remote_body" > "$tmp_file"
    
    if ! validate_bash_syntax "$tmp_file"; then
      return 0
    fi
    
    # Backup original
    local backup_file="${script_location}.backup"
    if ! cp "$script_location" "$backup_file" 2>/dev/null; then
      return 0
    fi
    
    # Install update
    if ! install -m 0755 "$tmp_file" "$script_location" 2>/dev/null; then
      # Restore backup if installation failed
      cp "$backup_file" "$script_location" 2>/dev/null || true
      return 0
    fi
    
    # Validate installation
    if ! validate_installation "$script_location" "linux-toolbox"; then
      # Restore backup if validation failed
      cp "$backup_file" "$script_location" 2>/dev/null || true
      return 0
    fi
    
    # Cleanup backup
    rm -f "$backup_file"
    
    log "✓ Auto-updated to version $remote_version (was: $VERSION)"
    
  ) &>/dev/null &
  
  # Don't wait for background process
  return 0
}

main() {
  load_config
  set_messages
  
  # Auto-check and update in background (non-blocking)
  auto_update_check

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
