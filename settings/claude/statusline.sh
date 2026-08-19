#!/usr/bin/env bash
# Claude Code status line — model · folder ·  branch, in Tokyo Night colors.
# Claude Code pipes session JSON to stdin; the first stdout line is displayed.
# Docs: https://code.claude.com/docs/en/statusline

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')"
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."')"
else
  model="Claude"
  dir="$PWD"
fi

branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"

teal=$'\033[38;2;115;218;202m'
blue=$'\033[38;2;122;162;247m'
purple=$'\033[38;2;187;154;247m'
dim=$'\033[2m'
reset=$'\033[0m'

out="${teal}${model}${reset} ${dim}·${reset} ${blue}${dir##*/}${reset}"
if [ -n "$branch" ]; then
  out="${out} ${dim}·${reset} ${purple} ${branch}${reset}"
fi

printf '%s' "$out"
