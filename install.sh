#!/usr/bin/env bash
#
# Single entrypoint. Detects where it is running and dispatches to the right
# installer in os/. Safe to re-run at any time — every step is idempotent.
#
#   ./install.sh              auto-detect (macOS / Linux / devcontainer)
#   ./install.sh macos        force a specific installer
#   ./install.sh linux
#   ./install.sh devcontainer
#
# GitHub Codespaces and the VSCode Dev Containers extension run this file
# automatically when this repo is configured as your dotfiles repository.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

detect_target() {
  if [ -n "${CODESPACES:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ] || [ -f /.dockerenv ]; then
    echo "devcontainer"
    return
  fi

  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      echo "unsupported" ;;
  esac
}

TARGET="${1:-$(detect_target)}"

case "$TARGET" in
  macos|linux|devcontainer)
    exec bash "$DOTFILES_DIR/os/$TARGET/install.sh"
    ;;
  *)
    echo "Unsupported platform: $TARGET (expected macos, linux, or devcontainer)" >&2
    exit 1
    ;;
esac
