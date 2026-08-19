#!/usr/bin/env bash
#
# macOS setup — guided, step-by-step installer for Homebrew apps, zsh +
# oh-my-zsh + starship, git, SSH keychain, and symlinked app settings.
#
# Interactive when run from a terminal (choose apps, confirm each step);
# fully automatic when run without a TTY.

set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/lib.sh"

[ "$(uname -s)" = "Darwin" ] || fail "this script is macOS-only — use ./install.sh"

STEP_TOTAL=7
print_banner "macOS"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Homebrew" "Package manager used for everything in the Brewfile."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew already installed"
elif confirm "Homebrew is missing — install it now?"; then
  /bin/bash -c "$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 600 https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  warn "skipping Homebrew — application install will be skipped too"
fi

# Make brew available in this shell (Apple Silicon and Intel paths).
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "Applications" "Pick which Brewfile formulae and casks to install."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not available — skipping applications"
elif confirm "Choose and install applications from the Brewfile?"; then
  trust_brew_taps
  choose_brew_packages
  if [ -n "$BREWFILE_TO_USE" ]; then
    # Guarded so one failing formula/cask (e.g. an app that already exists in
    # /Applications from a manual install) never aborts the remaining steps.
    brew bundle --file="$BREWFILE_TO_USE" \
      || warn "brew bundle reported issues — fix them and re-run ./install.sh"
  fi
else
  warn "skipping applications"
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
  # Store git HTTPS credentials in the macOS keychain (machine-local setting).
  if [ -z "$(git config --file "$HOME/.gitconfig.local" credential.helper || true)" ]; then
    git config --file "$HOME/.gitconfig.local" credential.helper osxkeychain
    ok "git credential.helper set to osxkeychain in ~/.gitconfig.local"
  fi

  # Filesystem monitor daemon — much faster `git status` in big repos.
  # macOS/Windows-only feature, so it lives in the machine-local config.
  if [ -z "$(git config --file "$HOME/.gitconfig.local" core.fsmonitor || true)" ]; then
    git config --file "$HOME/.gitconfig.local" core.fsmonitor true
    ok "git core.fsmonitor enabled in ~/.gitconfig.local"
  fi

  # delta — syntax-highlighted diff pager (from the Brewfile). Machine-local
  # so machines without delta keep git's default pager working.
  if [ -z "$(git config --file "$HOME/.gitconfig.local" core.pager || true)" ]; then
    git config --file "$HOME/.gitconfig.local" core.pager delta
    git config --file "$HOME/.gitconfig.local" interactive.diffFilter "delta --color-only"
    git config --file "$HOME/.gitconfig.local" delta.navigate true
    git config --file "$HOME/.gitconfig.local" delta.line-numbers true
    ok "git diffs paged through delta (in ~/.gitconfig.local)"
  fi
else
  warn "skipping git setup"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "SSH + Apple keychain" "Key generation and automatic passphrase loading."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Set up SSH (links ~/.ssh/config, keychain-backed key)?"; then
  setup_ssh_config

  SSH_KEY="$HOME/.ssh/id_ed25519"

  if [ ! -f "$SSH_KEY" ]; then
    if is_interactive; then
      email="$(git_email)"
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
else
  warn "skipping SSH setup"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "App settings" "Symlink Zed, VSCode, and Warp config; VSCode extensions."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Link editor/terminal settings and install VSCode extensions?"; then
  setup_zed
  setup_vscode
  install_vscode_extensions
  setup_warp
  setup_claude_code
  setup_gh
else
  warn "skipping app settings"
fi

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
step "macOS system settings" "defaults write tweaks — restarts Dock and Finder."
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

if confirm "Apply macOS system settings (Dock and Finder will restart)?"; then
  bash "$DOTFILES_DIR/os/macos/defaults.sh"
else
  warn "skipping system settings — run ./os/macos/defaults.sh later"
fi

# Desktop wallpaper — the repo ships one in assets/. macOS may show a one-time
# automation permission prompt for the terminal on first use.
if [ -f "$DOTFILES_DIR/assets/wallpaper.jpg" ] && confirm "Set the desktop wallpaper from assets/wallpaper.jpg?"; then
  if osascript -e 'tell application "System Events" to set picture of every desktop to "'"$DOTFILES_DIR"'/assets/wallpaper.jpg"' >/dev/null 2>&1; then
    ok "wallpaper set"
  else
    warn "could not set wallpaper — grant the terminal Automation permission and re-run"
  fi
fi

printf '\n'
ok "macOS setup complete — open a new terminal to load the new shell config"
