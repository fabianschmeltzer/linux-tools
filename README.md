# linux-toolbox

Personal baseline for small Linux helper scripts. This project provides an installer script that installs additional scripts into `$HOME/.local/bin` or a freely chosen target directory.

## Usage

Install directly from GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/fabianschmeltzer/linux-tools/main/install.sh | bash
```

```bash
linux-toolbox list
linux-toolbox install self
linux-toolbox install docker-start
linux-toolbox install docker-stop
linux-toolbox install maintenance-upgrade
linux-toolbox install bcache-monitor
linux-toolbox install all
linux-toolbox ui
linux-toolbox settings
linux-toolbox version
linux-toolbox check-update
linux-toolbox self-update
```

The install target can be customized with `LINUX_TOOLBOX_INSTALL_DIR`:

```bash
LINUX_TOOLBOX_INSTALL_DIR=/usr/local/bin ./linux-toolbox.sh install all
```

## Included templates

- `docker-start`: starts a Docker Compose project in the background.
- `docker-stop`: stops a Docker Compose project.
- `maintenance-upgrade`: runs `apt update`, `apt upgrade -y`, and `apt autoremove -y`.
- `bcache-monitor`: installs the Linux Bcache Monitor script.

You can also install custom scripts:

```bash
linux-toolbox install-file ./my-script.sh my-script
```
