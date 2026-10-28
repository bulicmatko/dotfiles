#!/usr/bin/env bash
# Claude Code status line in Tokyo Night colors, on two lines:
#   model · effort · session cost · context % · 5h usage · weekly usage
#   folder on branch
# Inside a linked git worktree the folder shows the repo name plus the worktree name.
# Usage shows only for claude.ai Pro and Max plans, once the session's first response arrives.
# Claude Code pipes session JSON to stdin; each stdout line is a status line row.
# Docs: https://code.claude.com/docs/en/statusline

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')"
  effort="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."')"
  worktree="$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')"
  context="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor')"
  cost="$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')"
  five_hour="$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty | floor')"
  seven_day="$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty | floor')"
else
  model="Claude"
  effort=""
  dir="$PWD"
  worktree=""
  context=""
  cost=""
  five_hour=""
  seven_day=""
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

line1="${teal}${model}${reset}"
if [ -n "$effort" ]; then
  line1="${line1} ${dim}·${reset} ${orange}${effort}${reset}"
fi
if [ -n "$cost" ]; then
  line1="${line1} ${dim}·${reset} ${yellow}\$$(printf '%.2f' "$cost")${reset}"
fi
if [ -n "$context" ]; then
  line1="${line1} ${dim}·${reset} $(percent_color "$context")${context}%${reset}"
fi
if [ -n "$five_hour" ]; then
  line1="${line1} ${dim}· 5h${reset} $(percent_color "$five_hour")${five_hour}%${reset}"
fi
if [ -n "$seven_day" ]; then
  line1="${line1} ${dim}· wk${reset} $(percent_color "$seven_day")${seven_day}%${reset}"
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
