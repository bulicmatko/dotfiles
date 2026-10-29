#!/usr/bin/env bash
# Claude Code status line in Tokyo Night colors, on two lines of at most 80 columns:
#   Fable 5.1 · xhigh · $5.31 · 16% · 5h 35% @ 18:00 · wk 6% [5%] @ Tue 02:00
#   dotfiles in worktree statusline-usage
# The first line is the model, effort, session cost, context use, then claude.ai plan
# usage for the 5-hour and weekly windows with the local time each one resets. The
# bracketed figure is the current model's own weekly limit, when it has one. Plan
# usage shows only for claude.ai plans, once the session's first response arrives.
# The second line is the folder and branch. Inside a linked git worktree it shows the
# repo name plus the worktree name, and a name that would push the line past 80
# columns is shortened with an ellipsis.
# Claude Code pipes session JSON to stdin; each stdout line is a status line row.
# Docs: https://code.claude.com/docs/en/statusline
#
# Claude Code sends the 5-hour and weekly usage itself. The current model's own weekly
# limit comes from the claude.ai usage endpoint behind /usage. A detached background
# call reads it with the Claude Code login, at most once every five minutes across all
# sessions, and caches the reply. Renders only read the cache.

input="$(cat)"

max_width=80
usage_url="https://api.anthropic.com/api/oauth/usage"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/claude-statusline"
usage_file="$cache_dir/usage.json"
stamp_file="$cache_dir/usage.stamp"
fetch_every=300  # seconds between endpoint calls, shared by every session
stale_after=1800 # seconds after which a cached reply is too old to show

# Seconds since the file changed, or a large number when it is missing.
file_age() {
  local mtime
  mtime="$(stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null)" || {
    echo 999999
    return
  }
  echo $(($(date +%s) - mtime))
}

# Local time for Unix epoch seconds, with BSD date on macOS or GNU date on Linux.
format_time() {
  [ -n "$1" ] || return
  date -r "$1" +"$2" 2>/dev/null || date -d "@$1" +"$2" 2>/dev/null
}

# The Claude Code login lives in the macOS Keychain, or in a file on Linux.
oauth_token() {
  local credentials=""
  if command -v security >/dev/null 2>&1; then
    credentials="$(security find-generic-password -s 'Claude Code-credentials' -w 2>/dev/null)"
  fi
  if [ -z "$credentials" ] && [ -r "$HOME/.claude/.credentials.json" ]; then
    credentials="$(cat "$HOME/.claude/.credentials.json")"
  fi
  printf '%s' "$credentials" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null
}

# The token goes to curl on stdin, so it never shows in the process list.
fetch_usage() {
  local token tmp
  token="$(oauth_token)"
  [ -n "$token" ] || return
  tmp="$usage_file.$$"
  if printf 'Authorization: Bearer %s\n' "$token" |
    curl -sf --max-time 10 -H @- -H 'anthropic-beta: oauth-2025-04-20' -o "$tmp" "$usage_url" &&
    jq -e 'type == "object"' "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$usage_file"
  else
    rm -f "$tmp"
  fi
}

# One jq call reads every field as shell assignments, which keeps each render quick.
if command -v jq >/dev/null 2>&1; then
  eval "$(printf '%s' "$input" | jq -r '
    def num: numbers | floor;
    @sh "model=\(.model.display_name // "Claude")",
    @sh "effort=\(.effort.level // "")",
    @sh "dir=\(.workspace.current_dir // ".")",
    @sh "worktree=\(.workspace.git_worktree // "")",
    @sh "context=\(.context_window.used_percentage // 0 | floor)",
    @sh "cost=\(.cost.total_cost_usd // "")",
    @sh "five_hour=\(.rate_limits.five_hour.used_percentage | num // "")",
    @sh "seven_day=\(.rate_limits.seven_day.used_percentage | num // "")",
    @sh "five_hour_reset=\(.rate_limits.five_hour.resets_at | num // "")",
    @sh "seven_day_reset=\(.rate_limits.seven_day.resets_at | num // "")"
  ')"
else
  model="Claude"
  effort=""
  dir="$PWD"
  worktree=""
  context=""
  cost=""
  five_hour=""
  seven_day=""
  five_hour_reset=""
  seven_day_reset=""
fi

# Plan usage in the input means a claude.ai login, so the usage endpoint applies.
model_week=""
if [ -n "$five_hour$seven_day" ] && command -v curl >/dev/null 2>&1; then
  if [ "$(file_age "$stamp_file")" -ge "$fetch_every" ]; then
    mkdir -p "$cache_dir" && touch "$stamp_file"
    (fetch_usage </dev/null >/dev/null 2>&1 &)
  fi

  if [ -r "$usage_file" ] && [ "$(file_age "$usage_file")" -lt "$stale_after" ]; then
    # A weekly limit scoped to one model carries the model's short name, such as Fable,
    # which starts the session's model display name, such as Fable 5.1.
    model_week="$(jq -r --arg model "$model" '
      first(.limits[]?
        | select(.kind == "weekly_scoped")
        | select((.scope.model.display_name // "") as $name | $name != "" and ($model | startswith($name)))
        | .percent | numbers | floor) // empty
    ' "$usage_file" 2>/dev/null)"
  fi
fi

branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"
# Claude Code names its worktree branches worktree-<name>, which would repeat the worktree name.
if [ -n "$worktree" ] && [ "$branch" = "worktree-${worktree}" ]; then
  branch=""
fi

folder="${dir##*/}"
if [ -n "$worktree" ]; then
  # The shared .git dir lives in the main checkout, so its parent is the repo's folder.
  common_dir="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ]; then
    common_dir="${common_dir%/.git}"
    folder="${common_dir##*/}"
  fi
fi

teal=$'\033[38;2;115;218;202m'
blue=$'\033[38;2;122;162;247m'
purple=$'\033[38;2;187;154;247m'
green=$'\033[38;2;158;206;106m'
yellow=$'\033[38;2;224;175;104m'
red=$'\033[38;2;247;118;142m'
dim=$'\033[2m'
reset=$'\033[0m'
sep="${dim}·${reset}"

# A percentage in green, turning yellow at the second argument and red at the third.
percent() {
  local color="$green"
  if [ "$1" -ge "$3" ]; then
    color="$red"
  elif [ "$1" -ge "$2" ]; then
    color="$yellow"
  fi
  printf '%s%s%%%s' "$color" "$1" "$reset"
}

# Context answers degrade well before the window fills, and every turn resends it,
# so context turns yellow at 40% and red at 70%.
context_percent() { percent "$1" 40 70; }

# Plan usage matters only near the limit. Claude Code warns at 75% of a limit and
# again at 95%, so plan figures turn yellow and red at those points.
plan_percent() { percent "$1" 75 95; }

# Effort uses the colors of Claude Code's effort picker, from its dark theme: yellow
# for low, green for medium, lavender for high and purple for xhigh. Max spreads the
# picker's rainbow across its letters. The picker animates xhigh and max, but a
# status line redraws at most once a second, too slow for smooth motion.
effort_low=$'\033[38;2;255;193;7m'
effort_medium=$'\033[38;2;78;186;101m'
effort_high=$'\033[38;2;177;185;249m'
effort_xhigh=$'\033[38;2;175;135;255m'
effort_rainbow=(
  $'\033[38;2;235;95;87m'
  $'\033[38;2;245;139;87m'
  $'\033[38;2;250;195;95m'
  $'\033[38;2;145;200;130m'
  $'\033[38;2;130;170;220m'
  $'\033[38;2;155;130;200m'
  $'\033[38;2;200;130;180m'
)

effort_label() {
  local i last out=""
  case "$1" in
    low) printf '%s%s%s' "$effort_low" "$1" "$reset" ;;
    medium) printf '%s%s%s' "$effort_medium" "$1" "$reset" ;;
    xhigh) printf '%s%s%s' "$effort_xhigh" "$1" "$reset" ;;
    max)
      last=$((${#1} - 1))
      for ((i = 0; i <= last; i++)); do
        out="${out}${effort_rainbow[i * 6 / (last > 0 ? last : 1)]}${1:i:1}"
      done
      printf '%s%s' "$out" "$reset"
      ;;
    high | *) printf '%s%s%s' "$effort_high" "$1" "$reset" ;;
  esac
}

# Dimmed "@ <time>" for a reset time in Unix epoch seconds, when one is known.
at_time() {
  local when
  when="$(format_time "$1" "$2")"
  if [ -n "$when" ]; then
    printf ' %s@ %s%s' "$dim" "$when" "$reset"
  fi
}

line1="${teal}${model}${reset}"
if [ -n "$effort" ]; then
  line1="${line1} ${sep} $(effort_label "$effort")"
fi
if [ -n "$cost" ]; then
  # Whole dollars from $100 up keep the widest line within 80 columns.
  if [ "${cost%%.*}" -ge 100 ] 2>/dev/null; then
    cost="\$$(printf '%.0f' "$cost")"
  else
    cost="\$$(printf '%.2f' "$cost")"
  fi
  line1="${line1} ${sep} ${yellow}${cost}${reset}"
fi
if [ -n "$context" ]; then
  line1="${line1} ${sep} $(context_percent "$context")"
fi
if [ -n "$five_hour" ]; then
  line1="${line1} ${sep} ${dim}5h${reset} $(plan_percent "$five_hour")$(at_time "$five_hour_reset" '%H:%M')"
fi
if [ -n "$seven_day" ]; then
  line1="${line1} ${sep} ${dim}wk${reset} $(plan_percent "$seven_day")"
  if [ -n "$model_week" ]; then
    line1="${line1} ${dim}[${reset}$(plan_percent "$model_week")${dim}]${reset}"
  fi
  line1="${line1}$(at_time "$seven_day_reset" '%a %H:%M')"
fi

# The location ends with the branch, the worktree or the folder, and that last name
# gives up columns when the line would run past the maximum width.
location_plain="$folder"
[ -n "$worktree" ] && location_plain="${location_plain} in worktree ${worktree}"
[ -n "$branch" ] && location_plain="${location_plain} on ${branch}"
overflow=$((${#location_plain} - max_width))
shorten() {
  local keep=$((${#1} - overflow - 1))
  if [ "$overflow" -gt 0 ] && [ "$keep" -ge 1 ]; then
    printf '%s…' "${1:0:keep}"
  else
    printf '%s' "$1"
  fi
}
if [ -n "$branch" ]; then
  branch="$(shorten "$branch")"
elif [ -n "$worktree" ]; then
  worktree="$(shorten "$worktree")"
else
  folder="$(shorten "$folder")"
fi

line2="${blue}${folder}${reset}"
if [ -n "$worktree" ]; then
  line2="${line2} ${dim}in worktree${reset} ${blue}${worktree}${reset}"
fi
if [ -n "$branch" ]; then
  line2="${line2} ${dim}on${reset} ${purple}${branch}${reset}"
fi

printf '%s\n%s' "$line1" "$line2"
