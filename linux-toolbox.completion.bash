#!/usr/bin/env bash
# Bash completion script for linux-toolbox

_linux_toolbox_completion() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="list install install-file ui settings version check-update self-update help"
  local install_options="self docker-start docker-stop maintenance-upgrade bcache-monitor all"

  if [[ ${COMP_CWORD} -eq 1 ]]; then
    COMPREPLY=($(compgen -W "${commands}" -- ${cur}))
  elif [[ "${prev}" == "install" ]]; then
    COMPREPLY=($(compgen -W "${install_options}" -- ${cur}))
  elif [[ "${prev}" == "install-file" && ${COMP_CWORD} -eq 3 ]]; then
    COMPREPLY=($(compgen -f -- ${cur}))
  fi

  return 0
}

complete -o bashdefault -o default -o nospace -F _linux_toolbox_completion linux-toolbox
