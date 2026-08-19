#!/usr/bin/env bash
#
# Linux setup (Debian/Ubuntu based) — guided, step-by-step installer for
# desktops and VPS boxes: zsh + oh-my-zsh + starship, git/ssh config, and
# editor settings linked so they are ready whenever the apps get installed.
#
# Interactive when run from a terminal; fully automatic without a TTY.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"

[ "$(uname -s)" = "Linux" ] || fail "this script is Linux-only — use ./install.sh"

# Root/sudo is only needed for the apt step — everything else lives in $HOME,
# so a machine without sudo still gets the full shell/git/ssh/editor setup.
SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

STEP_TOTAL=6
print_banner "Linux"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Packages" "zsh, git, curl, keychain, fzf, and zoxide via apt."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# zsh      — the shell itself
# git      — clones oh-my-zsh plugins (and everything else)
# curl     — fetches the oh-my-zsh installer
# keychain — keeps one ssh-agent alive across sessions (used in zsh/zshrc)
# fzf      — fuzzy Ctrl-R history and file finding (wired in zsh/zshrc)
# zoxide   — learned cd (wired in zsh/zshrc)
PKGS=(zsh git curl keychain fzf zoxide)

if ! command -v apt-get >/dev/null 2>&1; then
  warn "apt-get not found — install ${PKGS[*]} manually"
elif [ "$(id -u)" -ne 0 ] && [ -z "$SUDO" ]; then
  warn "no root and no sudo — skipping packages; install ${PKGS[*]} manually"
elif confirm "Install base packages via apt?"; then
  $SUDO apt-get update
  # One transaction first; if a package is unavailable on this release
  # (apt aborts the whole transaction for one unknown name), fall back to
  # one-by-one so the rest still install.
  if ! $SUDO apt-get install -y "${PKGS[@]}"; then
    warn "batch install failed — retrying packages one by one"
    for pkg in "${PKGS[@]}"; do
      $SUDO apt-get install -y "$pkg" || warn "could not install $pkg"
    done
  fi
else
  warn "skipping packages"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Shell" "oh-my-zsh + starship prompt + zsh-autosuggestions + nvm."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Set up zsh (links ~/.zshrc into this repo)?"; then
  setup_zsh
  setup_starship
  setup_nvm
else
  warn "skipping shell setup"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Git" "Aliases + shared config; machine overrides in ~/.gitconfig.local."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Set up git config (links ~/.gitconfig into this repo)?"; then
  setup_git
  # Cache git HTTPS credentials in memory (machine-local setting).
  if [ -z "$(git config --file "$HOME/.gitconfig.local" credential.helper || true)" ]; then
    git config --file "$HOME/.gitconfig.local" credential.helper cache
    ok "git credential.helper set to cache in ~/.gitconfig.local"
  fi
else
  warn "skipping git setup"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "SSH" "Config link and key generation."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Set up SSH (links ~/.ssh/config)?"; then
  setup_ssh_config

  if [ ! -f "$HOME/.ssh/id_ed25519" ] && is_interactive; then
    email="$(git_email)"
    info "generating SSH key for $email (you will be asked for a passphrase)"
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"
    ok "new public key — add it at https://github.com/settings/keys :"
    cat "$HOME/.ssh/id_ed25519.pub"
  fi
else
  warn "skipping SSH setup"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "App settings" "Zed and VSCode links (harmless before the apps exist)."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Link editor settings and install VSCode extensions?"; then
  setup_zed
  setup_vscode
  install_vscode_extensions
  setup_claude_code
  setup_gh
else
  warn "skipping app settings"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Default shell" "Make zsh the login shell."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Set zsh as the default shell?"; then
  set_default_shell_zsh
else
  warn "skipping default shell change"
fi

printf '\n'
ok "Linux setup complete — log out and back in to use zsh"
