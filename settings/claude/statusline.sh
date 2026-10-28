#!/usr/bin/env bash
# Claude Code status line in Tokyo Night colors, on two lines:
#   model: Opus 5.5 · effort: high · cost: $3.04 · context: 12% · session: 33% 17:00 · week: 5% Tue 02:00
#   folder on branch
# Session and week show plan usage with the local time each window resets. When the
# current model has its own weekly limit, such as Fable, it follows the week, and
# limit resets left out of the total come last.
# Inside a linked git worktree the folder shows the repo name plus the worktree name.
# Usage shows only for claude.ai plans, once the session's first response arrives.
# Claude Code pipes session JSON to stdin; each stdout line is a status line row.
# Docs: https://code.claude.com/docs/en/statusline
#
# Claude Code sends the 5-hour and weekly usage itself. The current model's own weekly
# limit and the limit resets left come from the claude.ai usage endpoint behind /usage.
# A detached background call reads it with the Claude Code login, at most once every
# five minutes across all sessions, and caches the reply. Renders only read the cache.

input="$(cat)"

usage_url="https://api.anthropic.com/api/oauth/usage?cedar_ember=1"
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

if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')"
  effort="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."')"
  worktree="$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')"
  context="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor')"
  cost="$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')"
  five_hour="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')"
  seven_day="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty | floor')"
  five_hour_reset="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty | floor')"
  seven_day_reset="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.resets_at // empty | floor')"
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
model_label=""
model_week=""
model_week_reset=""
resets_left=""
resets_total=""
if [ -n "$five_hour$seven_day" ] && command -v curl >/dev/null 2>&1; then
  if [ "$(file_age "$stamp_file")" -ge "$fetch_every" ]; then
    mkdir -p "$cache_dir" && touch "$stamp_file"
    (fetch_usage </dev/null >/dev/null 2>&1 &)
  fi

  if [ -r "$usage_file" ] && [ "$(file_age "$usage_file")" -lt "$stale_after" ]; then
    # A weekly limit scoped to one model carries the model's short name, such as Fable,
    # which starts the session's model display name, such as Fable 5.1.
    # Its resets_at is ISO 8601 with fractional seconds, which jq parses once trimmed.
    # Fields are split on the unit separator, because read merges runs of tabs and
    # would shift every value after an empty one.
    IFS=$'\x1f' read -r model_label model_week model_week_reset resets_left resets_total < <(
      jq -r --arg model "$model" '
        def epoch: (sub("\\.[0-9]+"; "") | sub("\\+00:00$"; "Z") | fromdateiso8601)? // "";
        (first(.limits[]?
          | select(.kind == "weekly_scoped")
          | select((.scope.model.display_name // "") as $name | $name != "" and ($model | startswith($name)))
          | [.scope.model.display_name, .percent, (.resets_at // "" | epoch)]) // ["", "", ""]) as $scoped
        | [.cedar_ember.grants[]? | select(.paused != true)] as $grants
        | ($grants | map(.resets_total // 0) | add // 0) as $total
        | $scoped + (if $total > 0 then [($grants | map(.resets_left // 0) | add), $total] else ["", ""] end)
        | map(tostring) | join("\u001f")
      ' "$usage_file" 2>/dev/null
    )
    model_week="${model_week%%.*}"
  fi
fi

branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"

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
orange=$'\033[38;2;255;158;100m'
red=$'\033[38;2;247;118;142m'
dim=$'\033[2m'
reset=$'\033[0m'

# Green below 50%, yellow below 80%, red from 80% up.
percent_color() {
  if [ "$1" -ge 80 ]; then
    printf '%s' "$red"
  elif [ "$1" -ge 50 ]; then
    printf '%s' "$yellow"
  else
    printf '%s' "$green"
  fi
}

# A usage percentage followed by its dimmed local reset time, when one is known.
usage() {
  local when
  when="$(format_time "$2" "$3")"
  printf '%s%s%%%s' "$(percent_color "$1")" "$1" "$reset"
  if [ -n "$when" ]; then
    printf ' %s%s%s' "$dim" "$when" "$reset"
  fi
}

line1="${dim}model:${reset} ${teal}${model}${reset}"
if [ -n "$effort" ]; then
  line1="${line1} ${dim}· effort:${reset} ${orange}${effort}${reset}"
fi
if [ -n "$cost" ]; then
  line1="${line1} ${dim}· cost:${reset} ${yellow}\$$(printf '%.2f' "$cost")${reset}"
fi
if [ -n "$context" ]; then
  line1="${line1} ${dim}· context:${reset} $(percent_color "$context")${context}%${reset}"
fi
if [ -n "$five_hour" ]; then
  line1="${line1} ${dim}· session:${reset} $(usage "$five_hour" "$five_hour_reset" '%H:%M')"
fi
if [ -n "$seven_day" ]; then
  line1="${line1} ${dim}· week:${reset} $(usage "$seven_day" "$seven_day_reset" '%a %H:%M')"
fi
if [ -n "$model_week" ]; then
  line1="${line1} ${dim}· ${model_label} week:${reset} $(usage "$model_week" "$model_week_reset" '%a %H:%M')"
fi
if [ -n "$resets_total" ]; then
  line1="${line1} ${dim}· limit resets:${reset} ${teal}${resets_left}/${resets_total}${reset}"
fi

line2="${blue}${folder}${reset}"
if [ -n "$worktree" ]; then
  line2="${line2} ${dim}in worktree${reset} ${blue}${worktree}${reset}"
fi
# Claude Code names its worktree branches worktree-<name>, which would repeat the worktree name.
if [ -n "$branch" ] && [ "$branch" != "worktree-${worktree}" ]; then
  line2="${line2} ${dim}on${reset} ${purple}${branch}${reset}"
fi

printf '%s\n%s' "$line1" "$line2"
