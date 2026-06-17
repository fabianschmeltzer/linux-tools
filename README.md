# linux-toolbox

Persönliche Baseline für kleine Linux-Hilfsscripts. Das Projekt stellt ein
Installer-Script bereit, mit dem weitere Scripts nach `$HOME/.local/bin` oder in
ein frei wählbares Zielverzeichnis installiert werden können.

## Nutzung

Direkt von GitHub installieren:

```bash
curl -fsSL https://raw.githubusercontent.com/fabianschmeltzer/linux-tools/refs/heads/main/install.sh | bash
```

```bash
linux-toolbox list
linux-toolbox install self
linux-toolbox install docker-start
linux-toolbox install docker-stop
linux-toolbox install maintenance-upgrade
linux-toolbox install all
linux-toolbox version
linux-toolbox check-update
linux-toolbox self-update
```

Das Installationsziel kann über `LINUX_TOOLBOX_INSTALL_DIR` angepasst werden:

```bash
LINUX_TOOLBOX_INSTALL_DIR=/usr/local/bin ./linux-toolbox.sh install all
```

## Enthaltene Templates

- `docker-start`: startet ein Docker-Compose-Projekt im Hintergrund.
- `docker-stop`: stoppt ein Docker-Compose-Projekt.
- `maintenance-upgrade`: führt `apt update`, `apt upgrade -y` und
  `apt autoremove -y` aus.

Eigene Scripts können ebenfalls installiert werden:

```bash
linux-toolbox install-file ./mein-script.sh mein-script
```
