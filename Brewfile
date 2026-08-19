# Brewfile — every application on a Mac, installed with one call:
#
#   brew bundle --file=Brewfile
#
# Check what is missing:        brew bundle check --file=Brewfile
# Remove everything unlisted:   brew bundle cleanup --file=Brewfile
# Regenerate from a machine:    brew bundle dump --file=Brewfile --force
#
# The trailing comment on each line doubles as its description in the
# interactive picker shown by ./install.sh.

tap "oven-sh/bun"      # third-party tap that provides the bun formula

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# CLI tools
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

brew "tree"            # print directory trees in the terminal
brew "gh"              # GitHub CLI — PRs, issues, auth from the terminal
brew "glab"            # GitLab CLI — same idea for GitLab
brew "mkcert"          # locally-trusted HTTPS certificates for dev servers

# Runtimes & languages
# (nvm itself is installed and kept up to date by the zsh-nvm plugin;
# the Docker CLI comes with the docker-desktop cask below)
brew "asdf"            # multi-language version manager (Erlang, Elixir, ...)
brew "oven-sh/bun/bun" # Bun — fast JS runtime, bundler, package manager
brew "deno"            # Deno — secure TypeScript/JavaScript runtime
brew "go"              # Go compiler and toolchain

# Infrastructure
brew "minikube"        # local single-node Kubernetes cluster
brew "terraform"       # infrastructure as code

# Misc
brew "ollama"          # run open-source LLMs locally from the terminal

# Native build dependencies — uncomment when building Erlang/Elixir via asdf
# or image tooling that needs them:
# brew "wxwidgets"     # GUI toolkit Erlang's observer needs at build time
# brew "fop"           # Apache FOP — Erlang docs build dependency
# brew "unixodbc"      # ODBC driver layer — Erlang :odbc module
# brew "vips"          # fast image processing (sharp/image pipelines)

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Editors & terminals
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "visual-studio-code" # VSCode — primary editor
cask "zed"                # Zed — fast native editor
cask "cursor"             # Cursor — AI-first VSCode fork
cask "warp"               # Warp — main terminal
cask "ghostty"            # Ghostty — minimal GPU-accelerated terminal

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Development apps
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "docker-desktop"     # Docker engine + GUI for macOS (ships the docker CLI)
cask "tableplus"          # database GUI (Postgres, MySQL, SQLite, ...)
cask "postman"            # API client for testing HTTP endpoints
cask "lens"               # Kubernetes IDE — browse clusters visually
cask "drawio"             # diagrams and flowcharts

# AI tooling
cask "claude"             # Claude desktop app
cask "claude-code"        # Claude Code desktop app
cask "codex-app"          # OpenAI Codex desktop app
cask "lm-studio"          # download and run local LLMs with a GUI
cask "supacode"           # desktop UI for running coding agents in parallel

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Browsers
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "arc"                # Arc browser
cask "google-chrome"      # Chrome — testing + fallback browser

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Communication
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "slack"              # team chat
cask "microsoft-teams"    # work meetings/chat
cask "microsoft-outlook"  # work email/calendar
cask "telegram-desktop"   # personal messaging
cask "whatsapp"           # personal messaging

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Utilities & other apps
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "1password"          # password manager
cask "moom"               # window manager — move/resize windows with shortcuts
cask "the-unarchiver"     # extract rar/7z/... archives Finder cannot open
cask "notion"             # notes and docs
cask "openvpn-connect"    # VPN client
cask "wireshark-app"      # Wireshark GUI network packet analyzer
cask "freecad"            # 3D CAD modeling

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Fonts
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

cask "font-monaspace"     # GitHub Monaspace — editor/terminal font (Argon)
cask "font-fira-code"     # Fira Code — ligature font used as fallback
