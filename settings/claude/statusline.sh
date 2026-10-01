#!/usr/bin/env bash
# Claude Code status line — model · folder ·  branch · context %, in Tokyo Night colors.
# Claude Code pipes session JSON to stdin; the first stdout line is displayed.
# Docs: https://code.claude.com/docs/en/statusline

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  model="$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')"
  dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // "."')"
  context="$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0 | floor')"
else
  model="Claude"
  dir="$PWD"
  context=""
fi

branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"

teal=$'\033[38;2;115;218;202m'
blue=$'\033[38;2;122;162;247m'
purple=$'\033[38;2;187;154;247m'
green=$'\033[38;2;158;206;106m'
yellow=$'\033[38;2;224;175;104m'
red=$'\033[38;2;247;118;142m'
dim=$'\033[2m'
reset=$'\033[0m'

out="${teal}${model}${reset} ${dim}·${reset} ${blue}${dir##*/}${reset}"
if [ -n "$branch" ]; then
  out="${out} ${dim}·${reset} ${purple} ${branch}${reset}"
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

printf '%s' "$out"
