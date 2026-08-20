# Brewfile — every application on a Mac, installed with one call:
#
#   brew bundle --file=Brewfile
#
# Check what is missing:        brew bundle check --file=Brewfile
# Remove everything unlisted:   brew bundle cleanup --file=Brewfile
# Regenerate from a machine:    brew bundle dump --file=Brewfile --force
#
# Sections group packages by what they are for, so a CLI tool sits next to the
# GUI app it belongs with. The installer's interactive picker reads them back:
# each section becomes a heading, and the trailing comment on each line becomes
# that line's description.
#
# A third-party tap sits directly above the package it provides. Trust is per
# machine (Homebrew stores it in ~/.homebrew/trust.json), so the installer asks
# once for every tap listed here.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Terminal & shell
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "warp"     # Warp — main terminal
brew "starship" # the prompt — configured in settings/starship/
brew "fzf"      # fuzzy finder — Ctrl-R history, **<Tab> completion
brew "zoxide"   # smarter cd — `z dotf` jumps to ~/Projects/dotfiles

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Files, text & system
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

brew "eza"     # modern ls — git status, icons (aliased in zshrc)
brew "bat"     # cat with syntax highlighting and paging
brew "tree"    # print directory trees in the terminal
brew "ripgrep" # rg — very fast recursive grep
brew "jq"      # command-line JSON processor
brew "btop"    # pretty resource monitor (htop successor)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Editors
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "visual-studio-code" # VSCode — primary editor
cask "zed"                # Zed — fast native editor
cask "cursor"             # Cursor — AI-first VSCode fork

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Git & code hosting
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

brew "git-delta" # syntax-highlighted git diff pager (wired per machine)
brew "gh"        # GitHub CLI — PRs, issues, auth from the terminal
brew "glab"      # GitLab CLI — same idea for GitLab

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Languages & runtimes
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

tap "oven-sh/bun"      # the only source of the bun formula
brew "oven-sh/bun/bun" # Bun — fast JS runtime, bundler, package manager
brew "deno"            # Deno — secure TypeScript/JavaScript runtime
brew "go"              # Go compiler and toolchain

# Node is absent on purpose: its versions are managed by nvm, which the install
# script fetches from upstream because nvm does not support Homebrew installs.

# Native build dependencies — uncomment when image tooling needs them:
# brew "vips"          # fast image processing (sharp/image pipelines)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Containers & infrastructure
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "docker-desktop" # Docker engine + GUI for macOS (ships the docker CLI)
brew "minikube"       # local single-node Kubernetes cluster
cask "lens"           # Kubernetes IDE — browse clusters visually

# Terraform ships from HashiCorp's tap rather than homebrew-core, which
# carries no terraform formula. OpenTofu (brew "opentofu") is the drop-in
# fork if a machine would rather stay on an open-source license.
tap "hashicorp/tap"   # HashiCorp's own tap — the only source of terraform
brew "hashicorp/tap/terraform" # infrastructure as code

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Web, APIs & databases
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "google-chrome" # Chrome — testing + fallback browser
cask "postman"       # API client for testing HTTP endpoints
brew "mkcert"        # locally-trusted HTTPS certificates for dev servers
cask "tableplus"     # database GUI (Postgres, MySQL, SQLite, ...)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# AI tooling
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "claude"      # Claude desktop app
cask "claude-code" # Claude Code desktop app
cask "codex-app"   # OpenAI Codex desktop app
cask "lm-studio"   # download and run local LLMs with a GUI
brew "ollama"      # run open-source LLMs locally from the terminal

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Notes, docs & planning
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "notion" # notes and docs
cask "linear" # Linear — issue tracking and project planning
cask "drawio" # diagrams and flowcharts

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Communication
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "slack"             # team chat
cask "microsoft-teams"   # work meetings/chat
cask "microsoft-outlook" # work email/calendar
cask "telegram-desktop"  # personal messaging
cask "whatsapp"          # personal messaging

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Security & networking
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "1password"       # password manager
cask "openvpn-connect" # VPN client
cask "wireshark-app"   # Wireshark GUI network packet analyzer

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# macOS utilities
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "moom"           # window manager — move/resize windows with shortcuts
cask "the-unarchiver" # extract rar/7z/... archives Finder cannot open
brew "mas"            # install Mac App Store apps from this file
# mas "Xcode", id: 497799835   # example — list App Store apps like this

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Fonts
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Nerd Font builds: same letterforms + ligatures, plus icon glyphs for
# starship presets, eza --icons, and TUI tools.
cask "font-monaspice-nerd-font" # GitHub Monaspace, patched — editor font ("MonaspiceAr NF")
cask "font-fira-code-nerd-font" # Fira Code, patched — editor/terminal fallback ("FiraCode Nerd Font")
