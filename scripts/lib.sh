# Shared helpers for all install scripts.
# Source this file, do not execute it:  source "$DOTFILES_DIR/scripts/lib.sh"

# Absolute path to the repo root, derived from this file's location so every
# script works no matter where it is invoked from.
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DOTFILES_DIR

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Logging
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

info() { printf '\033[34m[info]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[ ok ]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[warn]\033[0m %s\n' "$*"; }
fail() { printf '\033[31m[fail]\033[0m %s\n' "$*" >&2; exit 1; }

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Filesystem
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# link_file <repo-relative-source> <absolute-target>
#
# Idempotent symlink:
#   - already linked correctly  -> no-op
#   - stale symlink (old layout)-> replaced
#   - real file/dir in the way  -> moved to <target>.backup.<timestamp>
link_file() {
  local src="$DOTFILES_DIR/$1"
  local dst="$2"

  [ -e "$src" ] || fail "link source missing: $src"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      ok "already linked: $dst"
      return 0
    fi
    rm "$dst"
  elif [ -e "$dst" ]; then
    local backup
    backup="$dst.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dst" "$backup"
    warn "existing $dst moved to $backup"
  fi

  ln -s "$src" "$dst"
  ok "linked: $dst -> $src"
}

# clone_repo <url> <target-dir> — shallow clone, no-op when already cloned.
clone_repo() {
  if [ -d "$2/.git" ]; then
    ok "already cloned: $2"
  else
    info "cloning $1"
    git clone --depth=1 "$1" "$2"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Zsh / oh-my-zsh / spaceship
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zsh() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    ok "oh-my-zsh already installed"
  else
    info "installing oh-my-zsh"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  clone_repo https://github.com/spaceship-prompt/spaceship-prompt.git "$custom/themes/spaceship-prompt"
  if [ ! -e "$custom/themes/spaceship.zsh-theme" ]; then
    ln -s "$custom/themes/spaceship-prompt/spaceship.zsh-theme" "$custom/themes/spaceship.zsh-theme"
  fi

  clone_repo https://github.com/lukechilds/zsh-nvm.git "$custom/plugins/zsh-nvm"
  clone_repo https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"

  link_file zsh/zshrc "$HOME/.zshrc"
}

# set_default_shell_zsh — best effort, never fatal (chsh may prompt or be absent).
set_default_shell_zsh() {
  local zsh_path
  zsh_path="$(command -v zsh || true)"
  [ -n "$zsh_path" ] || { warn "zsh not found, skipping chsh"; return 0; }

  if [ "${SHELL:-}" = "$zsh_path" ]; then
    ok "zsh is already the default shell"
    return 0
  fi

  if chsh -s "$zsh_path" 2>/dev/null || ${SUDO:-} chsh -s "$zsh_path" "$USER" 2>/dev/null; then
    ok "default shell set to $zsh_path"
  else
    warn "could not change default shell — run: chsh -s $zsh_path"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Git
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_git() {
  link_file git/gitconfig "$HOME/.gitconfig"
  link_file git/gitignore_global "$HOME/.gitignore_global"
  link_file git/gitattributes "$HOME/.gitattributes"

  # Machine-specific overrides live outside the repo and win over gitconfig.
  if [ ! -f "$HOME/.gitconfig.local" ]; then
    cp "$DOTFILES_DIR/git/gitconfig.local.template" "$HOME/.gitconfig.local"
    ok "created ~/.gitconfig.local for machine-specific overrides"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SSH
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_ssh_config() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  link_file ssh/config "$HOME/.ssh/config"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# App settings (Zed, VSCode, Warp)
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_zed() {
  link_file settings/zed/settings.json "$HOME/.config/zed/settings.json"
  link_file settings/zed/keymap.json "$HOME/.config/zed/keymap.json"
}

# setup_vscode <vscode-user-dir>
setup_vscode() {
  local user_dir="$1"
  link_file settings/vscode/settings.json "$user_dir/settings.json"
  link_file settings/vscode/keybindings.json "$user_dir/keybindings.json"
}

install_vscode_extensions() {
  if ! command -v code >/dev/null 2>&1; then
    warn "'code' CLI not found, skipping VSCode extensions"
    return 0
  fi

  info "installing VSCode extensions"
  local installed extension
  installed="$(code --list-extensions 2>/dev/null)"
  while IFS= read -r extension; do
    case "$extension" in ''|'#'*) continue ;; esac
    if printf '%s\n' "$installed" | grep -qix "$extension"; then
      ok "extension already installed: $extension"
    else
      code --install-extension "$extension" || warn "failed to install $extension"
    fi
  done < "$DOTFILES_DIR/settings/vscode/extensions.txt"
}

setup_warp() {
  link_file settings/warp/settings.toml "$HOME/.warp/settings.toml"
  link_file settings/warp/themes "$HOME/.warp/themes"
}
