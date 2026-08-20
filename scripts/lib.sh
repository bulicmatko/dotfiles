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

# discard_escape_tail — swallow the rest of an escape sequence.
#
# A wheel scroll arrives as something like ESC [ < 64;10;10 M. Only the first
# three bytes are read before it is recognized as uninteresting; the rest must
# be dropped here, or the digits and letters left behind are read one by one
# as if they were keystrokes. Every such sequence ends with a byte in the
# @-to-~ range, and the timeout covers a lone Escape with no tail at all.
discard_escape_tail() {
  local ch
  while IFS= read -rsn1 -t 1 ch </dev/tty; do
    case "$ch" in
      [@A-Za-z~]) break ;;
    esac
  done
  return 0
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

    # An empty read is how Enter arrives (read -n1 swallows the newline as its
    # delimiter), so anything else that produces no usable key must say so
    # with a name of its own rather than an empty string — otherwise a mouse
    # wheel would confirm the selection and start installing.
    if IFS= read -rsn1 key </dev/tty; then
      if [ "$key" = $'\x1b' ]; then
        seq=""
        IFS= read -rsn2 -t 1 seq </dev/tty || true
        case "$seq" in
          '[A') key="up" ;;
          '[B') key="down" ;;
          # Scroll wheels, page keys, and a bare Escape all land here.
          *) discard_escape_tail; key="ignored" ;;
        esac
      fi
    else
      # The terminal went away; stop rather than spin on end-of-input.
      break
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
# Parses the Brewfile into the multiselect picker (section headers included,
# already-installed items annotated) and writes the selection to
# ~/.Brewfile.local — this machine's untracked subset, installed here and
# re-used by dotfiles-update so updates respect the choice. Sets
# BREWFILE_TO_USE; empty string means nothing was selected. Without a TTY the
# full Brewfile is used, matching unattended behavior.
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

  local selection="$HOME/.Brewfile.local" selected=0 skipped=0 i=0
  {
    printf '%s\n' "# ~/.Brewfile.local — this machine's Brewfile subset, written by the"
    printf '%s\n' "# installer's picker. dotfiles-update installs from it; re-run ./install.sh"
    printf '%s\n' "# to change the selection or pick up new Brewfile entries."
    grep '^tap ' "$DOTFILES_DIR/Brewfile" || true
  } > "$selection"

  while [ $i -lt ${#names[@]} ]; do
    if [ "${kinds[$i]}" != "header" ]; then
      if [ "${MS_CHECKED[$i]}" = "1" ]; then
        printf '%s "%s"\n' "${kinds[$i]}" "${names[$i]}" >> "$selection"
        selected=$((selected + 1))
      else
        skipped=$((skipped + 1))
      fi
    fi
    i=$((i + 1))
  done

  if [ $selected -eq 0 ]; then
    BREWFILE_TO_USE=""
    warn "no applications selected — skipping brew bundle"
  else
    BREWFILE_TO_USE="$selection"
    ok "$selected application(s) selected, $skipped skipped (saved to ~/.Brewfile.local)"
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
