# linux-toolbox

Persönliche Baseline für kleine Linux-Hilfsscripts. Das Projekt stellt ein
Installer-Script bereit, mit dem weitere Scripts nach `$HOME/.local/bin` oder in
ein frei wählbares Zielverzeichnis installiert werden können.

## Nutzung

```bash
./linux-toolbox.sh list
./linux-toolbox.sh install self
./linux-toolbox.sh install docker-start
./linux-toolbox.sh install docker-stop
./linux-toolbox.sh install maintenance-upgrade
./linux-toolbox.sh install all
./linux-toolbox.sh version
./linux-toolbox.sh check-update
./linux-toolbox.sh self-update
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
./linux-toolbox.sh install-file ./mein-script.sh mein-script
```
