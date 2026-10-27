#!/usr/bin/env bash
# Claude Code status line — model · effort · folder on branch · context % · session cost, in Tokyo Night colors.
# Inside a linked git worktree the folder shows the repo name plus the worktree name.
# Claude Code pipes session JSON to stdin; the first stdout line is displayed.
# Docs: https://code.claude.com/docs/en/statusline

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')"
  effort="$(printf '%s' "$input" | jq -r '.effort.level // empty')"
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."')"
  worktree="$(printf '%s' "$input" | jq -r '.workspace.git_worktree // empty')"
  context="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor')"
  cost="$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')"
else
  model="Claude"
  effort=""
  dir="$PWD"
  worktree=""
  context=""
  cost=""
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

out="${teal}${model}${reset}"
if [ -n "$effort" ]; then
  out="${out} ${dim}·${reset} ${orange}${effort}${reset}"
fi
out="${out} ${dim}·${reset} ${blue}${folder}${reset}"
if [ -n "$worktree" ]; then
  out="${out} ${dim}in worktree${reset} ${blue}${worktree}${reset}"
fi
# Claude Code names its worktree branches worktree-<name>, which would repeat the worktree name.
if [ -n "$branch" ] && [ "$branch" != "worktree-${worktree}" ]; then
  out="${out} ${dim}on${reset} ${purple}${branch}${reset}"
fi
if [ -n "$context" ]; then
  if [ "$context" -ge 80 ]; then
    color="$red"
  elif [ "$context" -ge 50 ]; then
    color="$yellow"
  else
    color="$green"
  fi
  out="${out} ${dim}·${reset} ${color}${context}%${reset}"
fi
if [ -n "$cost" ]; then
  out="${out} ${dim}·${reset} ${yellow}\$$(printf '%.2f' "$cost")${reset}"
fi

printf '%s' "$out"
