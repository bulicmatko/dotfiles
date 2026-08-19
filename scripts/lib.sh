# shellcheck shell=bash
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
# Guided install UI
#
# Everything here is plain bash 3.2 (macOS stock bash) with zero dependencies,
# and everything degrades gracefully: without a TTY the prompts auto-answer
# "yes" and the package picker selects everything, so devcontainers and
# Codespaces stay fully non-interactive.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

is_interactive() { [ -t 0 ] && [ -r /dev/tty ] && [ -w /dev/tty ]; }

# print_banner <target-label>
print_banner() {
  printf '\033[36m'
  cat <<'BANNER'

 _         _ _               _   _         __  _     _    __ _ _
| |__ _  _| (_)__ _ __  __ _| |_| |_____  / /_| |___| |_ / _(_) |___ ___
| '_ \ || | | / _| '  \/ _` |  _| / / _ \/ / _` / _ \  _|  _| | / -_|_-<
|_.__/\_,_|_|_\__|_|_|_\__,_|\__|_\_\___/_/\__,_\___/\__|_| |_|_\___/__/

BANNER
  printf '\033[0m'
  printf '  \033[2mtarget:\033[0m %s   \033[2muser:\033[0m %s   \033[2mhost:\033[0m %s\n\n' \
    "$1" "$(id -un)" "$(hostname -s 2>/dev/null || hostname)"
}

# step <title> [description] — numbered section header.
# Set STEP_TOTAL in the calling script before the first step.
STEP_NUM=0
step() {
  STEP_NUM=$((STEP_NUM + 1))
  printf '\n\033[1;35m── Step %s/%s · %s ──\033[0m\n' "$STEP_NUM" "${STEP_TOTAL:-?}" "$1"
  [ $# -ge 2 ] && printf '\033[2m%s\033[0m\n' "$2"
  return 0
}

# confirm <question> — returns 0 on yes (default), 1 on no. Auto-yes when
# there is no TTY so unattended runs proceed without blocking.
confirm() {
  local reply
  is_interactive || return 0
  printf '\033[36m?\033[0m %s \033[2m[Y/n]\033[0m ' "$1" >/dev/tty
  IFS= read -r reply </dev/tty
  case "$reply" in
    n|N|no|No|NO) return 1 ;;
    *) return 0 ;;
  esac
}

# ask <question> [default] — prints the answer on stdout. Enter accepts the
# default; without a TTY the default is used so unattended runs never block.
ask() {
  local question="$1" default="${2:-}" reply=""
  if is_interactive; then
    if [ -n "$default" ]; then
      printf '\033[36m?\033[0m %s \033[2m[%s]\033[0m ' "$question" "$default" >/dev/tty
    else
      printf '\033[36m?\033[0m %s ' "$question" >/dev/tty
    fi
    IFS= read -r reply </dev/tty
  fi
  [ -n "$reply" ] && printf '%s' "$reply" || printf '%s' "$default"
}

# multiselect <title>
#
# Checkbox picker on the terminal's alternate screen. Items are provided via
# three parallel global arrays (bash 3.2 has no namerefs):
#   MS_KINDS[i]   "item" or "header" (headers are display-only)
#   MS_LABELS[i]  text to show
#   MS_CHECKED[i] 1 = selected (updated in place with the user's choices)
# Keys: up/down or j/k move, space toggles, a = all, n = none, enter confirms.
multiselect() {
  local title="$1"
  local total=${#MS_LABELS[@]}
  local cursor=0 offset=0 i key seq rows cols window line mark pointer

  # Start on the first real item.
  while [ "${MS_KINDS[$cursor]}" = "header" ] && [ $cursor -lt $((total - 1)) ]; do
    cursor=$((cursor + 1))
  done

  # Leave the alternate screen intact on Ctrl-C, then re-raise the signal.
  trap 'printf "\033[?25h\033[?1049l" >/dev/tty; trap - INT; kill -INT $$' INT
  printf '\033[?1049h\033[?25l' >/dev/tty

  while true; do
    rows=$(stty size </dev/tty 2>/dev/null | awk '{print $1}'); rows=${rows:-24}
    cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}'); cols=${cols:-80}
    window=$((rows - 6)); [ $window -lt 3 ] && window=3

    # Keep the cursor inside the visible window.
    [ $cursor -lt $offset ] && offset=$cursor
    [ $cursor -ge $((offset + window)) ] && offset=$((cursor - window + 1))

    {
      printf '\033[H\033[2J'
      printf '\033[1m%s\033[0m\n' "$title"
      printf '\033[2mspace toggle · ↑/↓ move · a all · n none · enter confirm\033[0m\n'
      [ $offset -gt 0 ] && printf '\033[2m  ↑ more\033[0m\n' || printf '\n'

      i=$offset
      while [ $i -lt $((offset + window)) ] && [ $i -lt "$total" ]; do
        if [ "${MS_KINDS[$i]}" = "header" ]; then
          line="  \033[1;34m${MS_LABELS[$i]}\033[0m"
        else
          [ "${MS_CHECKED[$i]}" = "1" ] && mark="\033[32m[x]\033[0m" || mark="[ ]"
          line="  $mark ${MS_LABELS[$i]}"
        fi
        if [ $i -eq $cursor ]; then
          pointer="\033[36m›\033[0m"
        else
          pointer=" "
        fi
        # Truncate to the terminal width (escape codes make this approximate).
        printf "%b%b\033[0m\n" "$pointer" "$line" | cut -c 1-$((cols + 30))
        i=$((i + 1))
      done

      if [ $((offset + window)) -lt "$total" ]; then
        printf '\033[2m  ↓ more\033[0m\n'
      fi
    } >/dev/tty

    IFS= read -rsn1 key </dev/tty || key=""
    if [ "$key" = $'\x1b' ]; then
      seq=""
      IFS= read -rsn2 -t 1 seq </dev/tty || true
      case "$seq" in
        '[A') key="up" ;;
        '[B') key="down" ;;
        *) key="" ;;
      esac
    fi

    case "$key" in
      up|k)
        i=$cursor
        while [ $i -gt 0 ]; do
          i=$((i - 1))
          if [ "${MS_KINDS[$i]}" = "item" ]; then cursor=$i; break; fi
        done
        ;;
      down|j)
        i=$cursor
        while [ $i -lt $((total - 1)) ]; do
          i=$((i + 1))
          if [ "${MS_KINDS[$i]}" = "item" ]; then cursor=$i; break; fi
        done
        ;;
      ' ')
        if [ "${MS_CHECKED[$cursor]}" = "1" ]; then
          MS_CHECKED[cursor]=0
        else
          MS_CHECKED[cursor]=1
        fi
        ;;
      a)
        i=0
        while [ $i -lt "$total" ]; do
          [ "${MS_KINDS[$i]}" = "item" ] && MS_CHECKED[i]=1
          i=$((i + 1))
        done
        ;;
      n)
        i=0
        while [ $i -lt "$total" ]; do
          [ "${MS_KINDS[$i]}" = "item" ] && MS_CHECKED[i]=0
          i=$((i + 1))
        done
        ;;
      ''|$'\n'|$'\r')
        break
        ;;
    esac
  done

  printf '\033[?25h\033[?1049l' >/dev/tty
  trap - INT
}

# choose_brew_packages
#
# Parses the Brewfile into the multiselect picker (section headers included,
# already-installed items annotated) and writes the selection to a temporary
# Brewfile. Sets BREWFILE_TO_USE; empty string means nothing was selected.
# Without a TTY the full Brewfile is used, matching unattended behavior.
# shellcheck disable=SC2034  # BREWFILE_TO_USE is consumed by os/macos/install.sh
choose_brew_packages() {
  BREWFILE_TO_USE="$DOTFILES_DIR/Brewfile"
  is_interactive || return 0

  local parsed installed_formulae installed_casks
  parsed="$(awk '
    /^# - - / { dash = 1; next }
    dash && /^# [^-]/ { sub(/^# /, ""); print "header\t" $0 "\t"; dash = 0; next }
    { dash = 0 }
    /^(brew|cask) "/ {
      type = $1
      match($0, /"[^"]+"/)
      name = substr($0, RSTART + 1, RLENGTH - 2)
      desc = ""
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /# /)) { desc = substr(rest, RSTART + 2) }
      print type "\t" name "\t" desc
    }
  ' "$DOTFILES_DIR/Brewfile")"

  installed_formulae=" $(brew list --formula 2>/dev/null | tr '\n' ' ') "
  installed_casks=" $(brew list --cask 2>/dev/null | tr '\n' ' ') "

  MS_KINDS=() MS_LABELS=() MS_CHECKED=()
  local kinds=() names=()
  local kind name desc label short state

  while IFS=$'\t' read -r kind name desc; do
    [ -n "$kind" ] || continue
    if [ "$kind" = "header" ]; then
      MS_KINDS[${#MS_KINDS[@]}]="header"
      MS_LABELS[${#MS_LABELS[@]}]="$name"
      MS_CHECKED[${#MS_CHECKED[@]}]=0
      kinds[${#kinds[@]}]="header"; names[${#names[@]}]=""
      continue
    fi
    short="${name##*/}"
    state=""
    case "$kind" in
      brew) case "$installed_formulae" in *" $short "*) state=" (installed)";; esac ;;
      cask) case "$installed_casks"    in *" $short "*) state=" (installed)";; esac ;;
    esac
    label="$name"
    [ -n "$desc" ] && label="$label — $desc"
    [ -n "$state" ] && label="$label$state"
    MS_KINDS[${#MS_KINDS[@]}]="item"
    MS_LABELS[${#MS_LABELS[@]}]="$label"
    MS_CHECKED[${#MS_CHECKED[@]}]=1
    kinds[${#kinds[@]}]="$kind"; names[${#names[@]}]="$name"
  done <<EOF
$parsed
EOF

  multiselect "Select applications to install (all selected by default)"

  local tmp selected=0 skipped=0 i=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/dotfiles-brewfile.XXXXXX")"
  grep '^tap ' "$DOTFILES_DIR/Brewfile" > "$tmp" || true

  while [ $i -lt ${#names[@]} ]; do
    if [ "${kinds[$i]}" != "header" ]; then
      if [ "${MS_CHECKED[$i]}" = "1" ]; then
        printf '%s "%s"\n' "${kinds[$i]}" "${names[$i]}" >> "$tmp"
        selected=$((selected + 1))
      else
        skipped=$((skipped + 1))
      fi
    fi
    i=$((i + 1))
  done

  if [ $selected -eq 0 ]; then
    BREWFILE_TO_USE=""
    rm -f "$tmp"
    warn "no applications selected — skipping brew bundle"
  else
    BREWFILE_TO_USE="$tmp"
    ok "$selected application(s) selected, $skipped skipped"
  fi
}

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
# Zsh / oh-my-zsh / starship
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

  # The prompt is starship, not an oh-my-zsh theme — clear out the spaceship
  # clone and theme symlink if a previous setup left them behind.
  if [ -d "$custom/themes/spaceship-prompt" ] || [ -L "$custom/themes/spaceship.zsh-theme" ]; then
    rm -rf "$custom/themes/spaceship-prompt" "$custom/themes/spaceship.zsh-theme"
    ok "removed stale spaceship theme (the prompt is starship)"
  fi

  # zsh-autosuggestions — inline gray history suggestions, right-arrow accepts.
  clone_repo https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
  # zsh-syntax-highlighting — valid commands green, typos red, as you type.
  clone_repo https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"

  # nvm is wired directly in zsh/zshrc, not via a plugin — clear out the
  # zsh-nvm clone if a previous setup left one behind.
  if [ -d "$custom/plugins/zsh-nvm" ]; then
    rm -rf "$custom/plugins/zsh-nvm"
    ok "removed stale zsh-nvm plugin (nvm is wired directly in zshrc)"
  fi

  link_file zsh/zshrc "$HOME/.zshrc"
}

# setup_starship — the prompt. Config is linked for every platform; the
# binary comes from the Brewfile on macOS and the official installer
# elsewhere (single static binary into /usr/local/bin).
setup_starship() {
  link_file settings/starship/starship.toml "$HOME/.config/starship.toml"

  if command -v starship >/dev/null 2>&1 || command -v brew >/dev/null 2>&1; then
    return 0
  fi
  info "installing starship"
  curl -sS https://starship.rs/install.sh | sh -s -- -y || warn "starship install failed"
}

# setup_nvm — official installer, pinned release, no shell-profile edits
# (zsh/zshrc sources nvm and adds the .nvmrc auto-switch hook itself).
# nvm upstream does not support Homebrew installs, hence not in the Brewfile.
setup_nvm() {
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    ok "nvm already installed"
    return 0
  fi
  info "installing nvm"
  PROFILE=/dev/null bash -c "$(curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh)" \
    || warn "nvm install failed"
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
  # Capture any identity configured before ~/.gitconfig gets replaced (a
  # previous setup, or the identity Codespaces injects into containers) so
  # unattended runs keep committing as the right person.
  local existing_name existing_email
  existing_name="$(git config --global user.name 2>/dev/null || true)"
  existing_email="$(git config --global user.email 2>/dev/null || true)"

  link_file git/gitconfig "$HOME/.gitconfig"
  link_file git/gitignore_global "$HOME/.gitignore_global"
  link_file git/gitattributes "$HOME/.gitattributes"

  # Machine-specific overrides live outside the repo and win over gitconfig.
  if [ ! -f "$HOME/.gitconfig.local" ]; then
    cp "$DOTFILES_DIR/git/gitconfig.local.template" "$HOME/.gitconfig.local"
    ok "created ~/.gitconfig.local for machine-specific overrides"
  fi

  # Commit identity is per installation (the repo ships none, so these
  # dotfiles work for anyone without editing them). Asked once, stored in
  # ~/.gitconfig.local; skipped on every later run.
  local name email
  name="$(git config --file "$HOME/.gitconfig.local" user.name 2>/dev/null || true)"
  email="$(git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null || true)"

  if [ -z "$name" ]; then
    name="$(ask "Name for git commits:" "$existing_name")"
    if [ -n "$name" ]; then
      git config --file "$HOME/.gitconfig.local" user.name "$name"
      ok "git user.name set to '$name' in ~/.gitconfig.local"
    fi
  fi
  if [ -z "$email" ]; then
    email="$(ask "Email for git commits:" "$existing_email")"
    if [ -n "$email" ]; then
      git config --file "$HOME/.gitconfig.local" user.email "$email"
      ok "git user.email set to '$email' in ~/.gitconfig.local"
    fi
  fi
  if [ -z "$name" ] || [ -z "$email" ]; then
    warn "git identity incomplete — set it later with:"
    warn "  git config --file ~/.gitconfig.local user.name 'Your Name'"
    warn "  git config --file ~/.gitconfig.local user.email you@example.com"
  fi
}

# git_email — best available email (for the SSH key comment).
git_email() {
  git config --file "$HOME/.gitconfig.local" user.email 2>/dev/null \
    || git config user.email 2>/dev/null \
    || printf '%s@%s' "$(id -un)" "$(hostname -s 2>/dev/null || hostname)"
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# SSH
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

setup_ssh_config() {
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  link_file ssh/config "$HOME/.ssh/config"

  # Private hosts live outside the repo (Included from ssh/config).
  if [ ! -f "$HOME/.ssh/config.local" ]; then
    printf '# Machine-specific SSH hosts — NOT tracked in dotfiles.\n' > "$HOME/.ssh/config.local"
    ok "created ~/.ssh/config.local for private hosts"
  fi
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

setup_claude_code() {
  link_file settings/claude/settings.json "$HOME/.claude/settings.json"
  link_file settings/claude/statusline.sh "$HOME/.claude/statusline.sh"
}

# Only gh's config.yml is synced — hosts.yml holds auth tokens and must
# never enter the repo.
setup_gh() {
  link_file settings/gh/config.yml "$HOME/.config/gh/config.yml"
}
