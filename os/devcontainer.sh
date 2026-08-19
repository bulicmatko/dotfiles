#!/usr/bin/env bash
#
# Devcontainer / GitHub Codespaces setup — fully non-interactive and headless.
# Only the shell and git config are set up; SSH keys come in via agent
# forwarding and GUI app settings do not apply inside a container.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

print_banner "devcontainer"

export DEBIAN_FRONTEND=noninteractive

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Packages (best effort — many devcontainer images already ship these)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if command -v apt-get >/dev/null 2>&1; then
  if ! command -v zsh >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    info "installing base packages"
    $SUDO apt-get update || warn "apt-get update failed"
    # zsh (the shell), git (plugin clones), curl (oh-my-zsh installer)
    $SUDO apt-get install -y zsh git curl || warn "package install failed — continuing"
  fi
fi

command -v zsh >/dev/null 2>&1 || fail "zsh is not available in this container"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Shell + git
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zsh
setup_git

set_default_shell_zsh

ok "devcontainer setup complete"
