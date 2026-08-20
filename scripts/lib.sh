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
# Platform detection
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# detect_target — prints macos / linux / devcontainer / unsupported.
# Shared by install.sh (dispatch) and bin/dotfiles-doctor (target-aware checks).
detect_target() {
  if [ -n "${CODESPACES:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ] || [ -f /.dockerenv ]; then
    echo "devcontainer"
    return 0
  fi

  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

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

# prompt_text <question> [default] — the prompt string for the readline
# prompts below. The color codes sit between \001 and \002 markers, which
# tell readline they occupy no screen width; without them it miscounts the
# prompt and redraws an edited line over the top of it.
prompt_text() {
  if [ -n "${2:-}" ]; then
    printf '\001\033[36m\002?\001\033[0m\002 %s \001\033[2m\002[%s]\001\033[0m\002 ' "$1" "$2"
  else
    printf '\001\033[36m\002?\001\033[0m\002 %s ' "$1"
  fi
}

# Answers are read through readline (-e), so arrow keys, word jumps, and
# history work while typing instead of leaving raw escape codes in the value.
# The prompt goes to readline itself (-p) so it survives line redraws, and
# stderr is pointed at the terminal so the prompt still appears when the
# installer's output is redirected.

# confirm <question> — returns 0 on yes (default), 1 on no. Auto-yes when
# there is no TTY so unattended runs proceed without blocking.
confirm() {
  local reply
  is_interactive || return 0
  IFS= read -e -r -p "$(prompt_text "$1" "Y/n")" reply </dev/tty 2>/dev/tty
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
    IFS= read -e -r -p "$(prompt_text "$question" "$default")" reply </dev/tty 2>/dev/tty
  fi
  [ -n "$reply" ] && printf '%s' "$reply" || printf '%s' "$default"
}

# trust_brew_taps [brewfile]
#
# Homebrew refuses to load formulae and casks from a third-party tap until
# that tap is trusted, and trust is per-machine (~/.homebrew/trust.json),
# so it is confirmed once per machine rather than carried in the repo.
# Every tap the Brewfile declares is offered here; without a TTY they are
# trusted automatically, matching the rest of the unattended install.
trust_brew_taps() {
  local brewfile="${1:-$DOTFILES_DIR/Brewfile}" taps trusted tap

  command -v brew >/dev/null 2>&1 || return 0
  [ -f "$brewfile" ] || return 0
  # Homebrew builds without the trust gate have no `brew trust` command.
  brew trust --json=v1 >/dev/null 2>&1 || return 0

  taps="$(awk '/^[[:space:]]*tap[[:space:]]+"/ { gsub(/^[^"]*"|".*$/, ""); print }' "$brewfile")"
  [ -n "$taps" ] || return 0

  trusted="$(brew trust --json=v1 2>/dev/null || true)"

  while IFS= read -r tap; do
    [ -n "$tap" ] || continue
    # The closing quote keeps "owner/name" from matching "owner/name/formula".
    case "$trusted" in
      *"\"$tap\""*)
        ok "tap already trusted: $tap"
        continue
        ;;
    esac
    if confirm "Trust the third-party tap $tap (needed to install its packages)?"; then
      if brew trust --tap "$tap"; then
        ok "trusted tap: $tap"
      else
        warn "could not trust $tap — its packages will fail to install"
      fi
    else
      warn "$tap left untrusted — its packages will fail to install"
    fi
  done <<EOF
$taps
EOF
}

# choose_brew_packages
#
# Presents the Brewfile in fzf — every entry selected to begin with, its
# section and description alongside it, and the ones already on this machine
# marked — and writes what survives to ~/.Brewfile.local, this machine's
# untracked subset. dotfiles-update installs from that file, so a machine
# keeps its choice. Sets BREWFILE_TO_USE; an empty string means nothing was
# selected. Without a TTY the full Brewfile is used, matching unattended
# behavior.
# shellcheck disable=SC2034  # BREWFILE_TO_USE is consumed by os/macos/install.sh
choose_brew_packages() {
  BREWFILE_TO_USE="$DOTFILES_DIR/Brewfile"
  is_interactive || return 0

  # The picker runs on fzf, which the Brewfile installs anyway; fetching it
  # first is what lets a brand-new machine choose rather than take everything.
  if ! command -v fzf >/dev/null 2>&1; then
    info "installing fzf — the application picker runs on it"
    brew install fzf >/dev/null 2>&1 || true
  fi
  if ! command -v fzf >/dev/null 2>&1; then
    warn "fzf unavailable — installing the whole Brewfile"
    return 0
  fi

  local installed_formulae installed_casks entries selection selected total
  installed_formulae=" $(brew list --formula 2>/dev/null | tr '\n' ' ') "
  installed_casks=" $(brew list --cask 2>/dev/null | tr '\n' ' ') "

  # kind <tab> name <tab> label. Only the label is shown and filtered on, so
  # the section name travels with each entry and typing "browser" narrows to
  # that group — the job the old section headings did, minus the rows that
  # existed only to be skipped over.
  entries="$(awk -v formulae="$installed_formulae" -v casks="$installed_casks" '
    /^# - - / { dash = 1; next }
    dash && /^# [^-]/ { section = $0; sub(/^# /, "", section); dash = 0; next }
    { dash = 0 }
    /^(brew|cask) "/ {
      kind = $1
      match($0, /"[^"]+"/)
      name = substr($0, RSTART + 1, RLENGTH - 2)
      desc = ""
      rest = substr($0, RSTART + RLENGTH)
      if (match(rest, /# /)) { desc = substr(rest, RSTART + 2) }

      short = name
      sub(/.*\//, "", short)
      state = ""
      if (kind == "brew" && index(formulae, " " short " ")) { state = "  (installed)" }
      if (kind == "cask" && index(casks, " " short " "))    { state = "  (installed)" }

      label = sprintf("%-26s %s", name, desc)
      if (section != "") { label = label "  · " section }
      print kind "\t" name "\t" label state
    }
  ' "$DOTFILES_DIR/Brewfile")"

  # fzf exits non-zero when the picker is dismissed, which reads the same as
  # selecting nothing: install none of it rather than all of it.
  selection="$(printf '%s\n' "$entries" | fzf \
    --multi \
    --delimiter=$'\t' \
    --with-nth=3 \
    --bind 'load:select-all,ctrl-a:select-all,ctrl-d:deselect-all' \
    --header='tab toggle · type to filter · ctrl-a / ctrl-d whole matches · enter confirm · esc skip' \
    --prompt='applications › ' \
    --pointer='›' \
    --marker='x ' \
    --no-mouse)" || true

  local selection_file="$HOME/.Brewfile.local"
  {
    printf '%s\n' "# ~/.Brewfile.local — this machine's Brewfile subset, written by the"
    printf '%s\n' "# installer's picker. dotfiles-update installs from it; re-run ./install.sh"
    printf '%s\n' "# to change the selection or pick up new Brewfile entries."
    grep '^tap ' "$DOTFILES_DIR/Brewfile" || true
  } > "$selection_file"

  selected=0
  while IFS=$'\t' read -r kind name _label; do
    [ -n "$kind" ] || continue
    printf '%s "%s"\n' "$kind" "$name" >> "$selection_file"
    selected=$((selected + 1))
  done <<EOF
$selection
EOF

  total="$(printf '%s\n' "$entries" | grep -c . || true)"

  if [ "$selected" -eq 0 ]; then
    BREWFILE_TO_USE=""
    rm -f "$selection_file"
    warn "no applications selected — skipping brew bundle"
  else
    BREWFILE_TO_USE="$selection_file"
    ok "$selected of $total application(s) selected (saved to ~/.Brewfile.local)"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Symlink manifest
#
# The single source of truth for what gets linked where. The setup_* helpers
# link through it (link_entry) and bin/dotfiles-doctor checks against it, so
# the installer and the doctor can never disagree about what a healthy
# machine looks like.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# vscode_user_dir — VSCode's per-OS user-settings directory.
vscode_user_dir() {
  if [ "$(uname -s)" = "Darwin" ]; then
    printf '%s' "$HOME/Library/Application Support/Code/User"
  else
    printf '%s' "$HOME/.config/Code/User"
  fi
}

# dotfiles_links <macos|linux|devcontainer> — emit the manifest as
# "repo-relative-source<TAB>absolute-target" lines for the given target.
# "macos" is the superset; "devcontainer" is the headless subset (shell,
# prompt, and git only).
dotfiles_links() {
  local target="$1"

  printf '%s\t%s\n' "zsh/zshrc" "$HOME/.zshrc"
  printf '%s\t%s\n' "settings/starship/starship.toml" "$HOME/.config/starship.toml"
  printf '%s\t%s\n' "git/gitconfig" "$HOME/.gitconfig"
  printf '%s\t%s\n' "git/gitignore_global" "$HOME/.gitignore_global"
  printf '%s\t%s\n' "git/gitattributes" "$HOME/.gitattributes"

  if [ "$target" = "devcontainer" ]; then
    return 0
  fi

  printf '%s\t%s\n' "ssh/config" "$HOME/.ssh/config"
  printf '%s\t%s\n' "settings/zed/settings.json" "$HOME/.config/zed/settings.json"
  printf '%s\t%s\n' "settings/zed/keymap.json" "$HOME/.config/zed/keymap.json"
  printf '%s\t%s\n' "settings/claude/settings.json" "$HOME/.claude/settings.json"
  printf '%s\t%s\n' "settings/claude/statusline.sh" "$HOME/.claude/statusline.sh"
  printf '%s\t%s\n' "settings/gh/config.yml" "$HOME/.config/gh/config.yml"
  printf '%s\t%s\n' "settings/vscode/settings.json" "$(vscode_user_dir)/settings.json"
  printf '%s\t%s\n' "settings/vscode/keybindings.json" "$(vscode_user_dir)/keybindings.json"

  if [ "$target" = "macos" ]; then
    printf '%s\t%s\n' "settings/warp/settings.toml" "$HOME/.warp/settings.toml"
    printf '%s\t%s\n' "settings/warp/themes" "$HOME/.warp/themes"
  fi
  return 0
}

# link_entry <repo-relative-source> — link one manifest entry, looking the
# target path up in dotfiles_links (the "macos" superset carries every entry).
# awk reads the whole manifest rather than exiting on the match: an early
# exit closes the pipe and the manifest's remaining writes would take
# SIGPIPE, which pipefail turns into a failed install step.
link_entry() {
  local src="$1" dst
  dst="$(dotfiles_links macos | awk -F '\t' -v s="$src" '$1 == s { print $2 }')"
  [ -n "$dst" ] || fail "no manifest entry for: $src"
  link_file "$src" "$dst"
}

# with_heartbeat <label> <command> [args...]
#
# Runs a long command and prints how long it has been going every 20 seconds,
# so a big download reads as progress rather than a stalled script.
#
# The command keeps the terminal: its output is never captured and it runs in
# the foreground. That matters more than a tidier animation — some casks ask
# for a password partway through, and a spinner drawn over that prompt (or a
# command pushed into the background, where reading the terminal would stop
# it) turns a five-minute install into one that waits forever for a password
# nobody was asked for.
with_heartbeat() {
  local label="$1"; shift
  local heartbeat_pid status

  # Unattended runs have nobody to reassure, and their logs read better
  # without the interruptions.
  if ! is_interactive; then
    "$@"
    return $?
  fi

  (
    elapsed=0
    while true; do
      sleep 20
      elapsed=$((elapsed + 20))
      printf '\033[2m   … still %s (%ss)\033[0m\n' "$label" "$elapsed" >/dev/tty
    done
  ) &
  heartbeat_pid=$!

  if "$@"; then status=0; else status=$?; fi

  kill "$heartbeat_pid" 2>/dev/null || true
  wait "$heartbeat_pid" 2>/dev/null || true
  return $status
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
    # Fetch first, run second: a failed download is a hard error instead of
    # silently executing an empty script.
    local omz_installer
    if omz_installer="$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 \
        https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      && [ -n "$omz_installer" ]; then
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$omz_installer" "" --unattended
    fi
    [ -d "$HOME/.oh-my-zsh" ] || fail "oh-my-zsh install failed — check your network and re-run ./install.sh"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

  # zsh-autosuggestions — inline gray history suggestions, right-arrow accepts.
  clone_repo https://github.com/zsh-users/zsh-autosuggestions.git "$custom/plugins/zsh-autosuggestions"
  # zsh-syntax-highlighting — valid commands green, typos red, as you type.
  clone_repo https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"

  link_entry zsh/zshrc
}

# setup_starship — the prompt. Links the config and makes sure the binary
# exists: the Brewfile provides it on macOS when selected, and the official
# installer covers every other case (single static binary into /usr/local/bin).
setup_starship() {
  link_entry settings/starship/starship.toml

  if command -v starship >/dev/null 2>&1; then
    ok "starship already installed"
    return 0
  fi
  info "installing starship"
  curl -sS --retry 3 --connect-timeout 10 --max-time 300 https://starship.rs/install.sh \
    | sh -s -- -y || warn "starship install failed — re-run ./install.sh to retry"
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
  # Fetch first, run second: a failed download warns instead of silently
  # executing an empty script.
  local nvm_installer
  if nvm_installer="$(curl -fsSL --retry 3 --connect-timeout 10 --max-time 300 \
      https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.7/install.sh)" \
    && [ -n "$nvm_installer" ]; then
    PROFILE=/dev/null bash -c "$nvm_installer" || warn "nvm install failed"
  else
    warn "could not download the nvm installer — re-run ./install.sh to retry"
  fi
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

  if chsh -s "$zsh_path" 2>/dev/null || ${SUDO:-} chsh -s "$zsh_path" "${USER:-$(id -un)}" 2>/dev/null; then
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

  link_entry git/gitconfig
  link_entry git/gitignore_global
  link_entry git/gitattributes

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
  link_entry ssh/config

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
  link_entry settings/zed/settings.json
  link_entry settings/zed/keymap.json
}

# setup_vscode — targets come from the manifest (vscode_user_dir picks the
# per-OS settings directory).
setup_vscode() {
  link_entry settings/vscode/settings.json
  link_entry settings/vscode/keybindings.json
}

install_vscode_extensions() {
  if ! command -v code >/dev/null 2>&1; then
    warn "'code' CLI not found, skipping VSCode extensions"
    return 0
  fi

  info "installing VSCode extensions"
  local installed extension
  installed="$(code --list-extensions 2>/dev/null || true)"
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
  link_entry settings/warp/settings.toml
  link_entry settings/warp/themes
}

setup_claude_code() {
  link_entry settings/claude/settings.json
  link_entry settings/claude/statusline.sh
}

# Only gh's config.yml is synced — hosts.yml holds auth tokens and must
# never enter the repo.
setup_gh() {
  link_entry settings/gh/config.yml
}
