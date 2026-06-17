# linux-tools

Persönliche Baseline für kleine Linux-Hilfsscripts. Das Projekt stellt ein
Installer-Script bereit, mit dem weitere Scripts nach `$HOME/.local/bin` oder in
ein frei wählbares Zielverzeichnis installiert werden können.

## Nutzung

```bash
./linux-tools.sh list
./linux-tools.sh install self
./linux-tools.sh install docker-start
./linux-tools.sh install docker-stop
./linux-tools.sh install maintenance-upgrade
./linux-tools.sh install all
```

Das Installationsziel kann über `LINUX_TOOLS_INSTALL_DIR` angepasst werden:

```bash
LINUX_TOOLS_INSTALL_DIR=/usr/local/bin ./linux-tools.sh install all
```

## Enthaltene Templates

- `docker-start`: startet ein Docker-Compose-Projekt im Hintergrund.
- `docker-stop`: stoppt ein Docker-Compose-Projekt.
- `maintenance-upgrade`: führt `apt update`, `apt upgrade -y` und
  `apt autoremove -y` aus.

Eigene Scripts können ebenfalls installiert werden:

```bash
./linux-tools.sh install-file ./mein-script.sh mein-script
```
