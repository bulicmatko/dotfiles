#!/usr/bin/env bash
#
# Linux setup (Debian/Ubuntu based) — for desktops and VPS boxes.
# Installs zsh + oh-my-zsh + spaceship, links git/ssh config, and links
# editor settings so they are ready whenever the apps get installed.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

[ "$(uname -s)" = "Linux" ] || fail "this script is Linux-only — use ./install.sh"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || fail "need root or sudo to install packages"
  SUDO="sudo"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Packages
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if command -v apt-get >/dev/null 2>&1; then
  info "installing base packages"
  $SUDO apt-get update
  # keychain keeps a single ssh-agent alive across sessions (see zsh/zshrc)
  $SUDO apt-get install -y zsh git curl keychain
else
  warn "apt-get not found — install zsh, git, curl, and keychain manually"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Shell + git + ssh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zsh
setup_git
setup_ssh_config

# Cache git HTTPS credentials in memory (machine-local setting).
if [ -z "$(git config --file "$HOME/.gitconfig.local" credential.helper || true)" ]; then
  git config --file "$HOME/.gitconfig.local" credential.helper cache
  ok "git credential.helper set to cache in ~/.gitconfig.local"
fi

if [ ! -f "$HOME/.ssh/id_ed25519" ] && [ -t 0 ]; then
  email="$(git config --file "$DOTFILES_DIR/git/gitconfig" user.email)"
  info "generating SSH key for $email (you will be asked for a passphrase)"
  ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"
  ok "new public key — add it at https://github.com/settings/keys :"
  cat "$HOME/.ssh/id_ed25519.pub"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# App settings (linked even before the apps are installed — harmless)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zed
setup_vscode "$HOME/.config/Code/User"
install_vscode_extensions

set_default_shell_zsh

ok "Linux setup complete — log out and back in to use zsh"
