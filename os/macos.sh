#!/usr/bin/env bash
#
# macOS setup — Homebrew apps, zsh + oh-my-zsh + spaceship, git, SSH keychain,
# and symlinked settings for Zed, VSCode, and Warp.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/lib.sh"

[ "$(uname -s)" = "Darwin" ] || fail "this script is macOS-only — use ./install.sh"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Homebrew + applications
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ! command -v brew >/dev/null 2>&1; then
  info "installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make brew available in this shell (Apple Silicon and Intel paths).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

info "installing applications from Brewfile"
brew bundle --file="$DOTFILES_DIR/Brewfile"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Shell + git + ssh
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zsh
setup_git
setup_ssh_config

# Store git HTTPS credentials in the macOS keychain (machine-local setting).
if [ -z "$(git config --file "$HOME/.gitconfig.local" credential.helper || true)" ]; then
  git config --file "$HOME/.gitconfig.local" credential.helper osxkeychain
  ok "git credential.helper set to osxkeychain in ~/.gitconfig.local"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SSH key + Apple keychain
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

SSH_KEY="$HOME/.ssh/id_ed25519"

if [ ! -f "$SSH_KEY" ]; then
  if [ -t 0 ]; then
    email="$(git config --file "$DOTFILES_DIR/git/gitconfig" user.email)"
    info "generating SSH key for $email (you will be asked for a passphrase)"
    ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY"
    ok "new public key — add it at https://github.com/settings/keys :"
    cat "$SSH_KEY.pub"
  else
    warn "no SSH key at $SSH_KEY and no TTY — skipping key generation"
  fi
fi

if [ -f "$SSH_KEY" ]; then
  # Stores the passphrase in the Apple keychain; combined with UseKeychain +
  # AddKeysToAgent in ssh/config the key loads automatically from then on.
  ssh-add --apple-use-keychain "$SSH_KEY" || warn "could not add key to keychain"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# App settings
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zed
setup_vscode "$HOME/Library/Application Support/Code/User"
install_vscode_extensions
setup_warp

ok "macOS setup complete — open a new terminal to load the new shell config"
