# bulicmatko/dotfiles

Personal dotfiles — the single source of truth for every machine I use:
macOS laptops, Linux boxes, and devcontainers/Codespaces.

Everything is **symlinked** from this repo into place, so editing a setting in
any tool changes the file *in this repo*. Commit and push on one machine,
pull on another — done.

## Layout

```
devcontainer/
  devcontainer.example.json   starter devcontainer for new projects
git/
  gitattributes               global git attributes
  gitconfig                   aliases + shared config
  gitconfig.local.template    seed for machine-specific ~/.gitconfig.local
  gitignore_global            global ignores (OS/editor junk)
os/
  devcontainer.sh             devcontainer / Codespaces installer (headless)
  linux.sh                    Linux (Debian/Ubuntu) installer
  macos-defaults.sh           macOS system + Finder settings (defaults write)
  macos.sh                    macOS installer
scripts/
  lib.sh                      shared helpers (linking, cloning, guided UI)
settings/
  vscode/
    extensions.txt            VSCode extension list
    keybindings.json          VSCode shortcuts
    settings.json             VSCode settings
  warp/
    themes/
      tokyo_night_storm.yml   custom Warp theme
    settings.toml             Warp settings
  zed/
    keymap.json               Zed shortcuts
    settings.json             Zed settings
ssh/
  config                      keychain-aware, valid on macOS and Linux
zsh/
  zshrc                       oh-my-zsh + spaceship, cross-platform
.editorconfig                 editor defaults for files in this repo
Brewfile                      every macOS app/CLI, installed in one call
install.sh                    entrypoint — detects the platform and dispatches
LICENSE                       MIT
README.md                     this file
```

## Fresh machine setup

```sh
git clone https://github.com/bulicmatko/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh
```

That is the whole setup. `install.sh` detects the platform; you can also force
one with `./install.sh macos|linux|devcontainer`. Every step is idempotent —
re-run it any time (e.g. after adding a new symlinked file). Files that would
be overwritten are backed up as `<name>.backup.<timestamp>`, never deleted.

When run from a terminal the installer is **guided**: it shows a banner, walks
through numbered steps, and asks before each one (Enter = yes). The
applications step opens a checkbox picker built from the Brewfile — so the
Brewfile can list *everything*, and each machine installs only what it needs:

```
space toggle · ↑/↓ (or j/k) move · a select all · n select none · enter confirm
```

Already-installed packages are annotated, and everything starts selected.
Without a TTY (Codespaces, scripted runs) there are no prompts: every step
runs and the full Brewfile is installed, so unattended setups never hang
waiting for input.

### What it does on macOS

1. Installs Homebrew if missing, then `brew bundle` with the [Brewfile](Brewfile)
2. Installs oh-my-zsh (unattended) + spaceship prompt + zsh-nvm + zsh-autosuggestions
3. Symlinks zsh, git, and ssh config (see table below)
4. Generates an ed25519 SSH key if missing and stores its passphrase in the
   **Apple keychain** (`ssh-add --apple-use-keychain`); `ssh/config` has
   `UseKeychain` + `AddKeysToAgent`, so the key auto-loads forever after
5. Sets git's credential helper to `osxkeychain` (in `~/.gitconfig.local`)
6. Symlinks Zed, VSCode, and Warp settings; installs VSCode extensions from
   [extensions.txt](settings/vscode/extensions.txt)
7. Applies macOS system settings via [os/macos-defaults.sh](os/macos-defaults.sh)
   — keyboard repeat, tap to click, Finder view/search/hidden files, Dock
   behavior — so System Settings never needs a manual walkthrough. Also runs
   standalone: `./os/macos-defaults.sh` (restarts Dock and Finder; some
   changes need a logout). Extra opt-in tweaks are included commented out.

### What it does on Linux

Installs `zsh git curl keychain` via apt, sets up the same shell/git/ssh
config, links editor settings, and makes zsh the default shell. `keychain`
keeps one ssh-agent alive across sessions (wired up in `zsh/zshrc`).

### What it does in devcontainers

Headless subset: zsh + oh-my-zsh + spaceship + git config only. No SSH keys
(agent forwarding provides them) and no GUI settings.

## Symlink map

| Repo file                          | Linked to                                             |
| ---------------------------------- | ----------------------------------------------------- |
| `git/gitattributes`                | `~/.gitattributes`                                    |
| `git/gitconfig`                    | `~/.gitconfig`                                        |
| `git/gitignore_global`             | `~/.gitignore_global`                                 |
| `settings/vscode/keybindings.json` | same VSCode User dir as settings.json                 |
| `settings/vscode/settings.json`    | `~/Library/Application Support/Code/User/settings.json` (macOS) / `~/.config/Code/User/settings.json` (Linux) |
| `settings/warp/themes/`            | `~/.warp/themes` (macOS)                              |
| `settings/warp/settings.toml`      | `~/.warp/settings.toml` (macOS)                       |
| `settings/zed/keymap.json`         | `~/.config/zed/keymap.json`                           |
| `settings/zed/settings.json`       | `~/.config/zed/settings.json`                         |
| `ssh/config`                       | `~/.ssh/config`                                       |
| `zsh/zshrc`                        | `~/.zshrc`                                            |

## Keeping machines in sync

Because everything is symlinked, tweaking a setting inside VSCode/Zed/Warp
edits this repo directly:

```sh
cd ~/Projects/dotfiles
git status        # see what changed
git commit -am "tune zed terminal font"
git push
```

On the other laptop: `git pull` — settings apply immediately (restart the app
if it caches config). Since this repo is the source of truth, consider turning
the tools' own settings-sync off to avoid tug-of-war.

## Machine-specific overrides (not tracked)

| File                | Purpose                                              |
| ------------------- | ---------------------------------------------------- |
| `~/.zshrc.local`    | extra shell config, sourced at the end of `zshrc`    |
| `~/.gitconfig.local`| git overrides (work email, credential helper, ...) — included last, wins over `gitconfig` |

## Homebrew (macOS apps)

The [Brewfile](Brewfile) is the app manifest. One call installs everything:

```sh
brew bundle --file=~/Projects/dotfiles/Brewfile
```

- After installing something new: `brew bundle dump --file=Brewfile --force`
  (then review the diff — it will also pick up dependencies you may not want
  listed) or just add the line by hand.
- `brew bundle cleanup --file=Brewfile` shows what is installed but not listed.
- nvm is intentionally **not** in the Brewfile — the `zsh-nvm` plugin installs
  and updates it in `~/.nvm`.

## Devcontainers

Two pieces make containers feel like home:

1. **Personal config, automatic**: VSCode's
   `"dotfiles.repository": "bulicmatko/dotfiles"` (already in
   [settings/vscode/settings.json](settings/vscode/settings.json)) clones this
   repo into every container and runs `install.sh`. For GitHub Codespaces,
   enable it once at <https://github.com/settings/codespaces> → *Automatically
   install dotfiles* → select this repo.
2. **Project config, per repo**: copy
   [devcontainer/devcontainer.example.json](devcontainer/devcontainer.example.json)
   to `<project>/.devcontainer/devcontainer.json` and adjust. Keep it
   team-neutral — personal config arrives via step 1.

## SSH keys on a brand-new Mac

`os/macos.sh` generates `~/.ssh/id_ed25519` if missing and stores the
passphrase in the Apple keychain. Add the printed public key to
[GitHub](https://github.com/settings/keys), then switch this repo's remote to
SSH if it was cloned over HTTPS:

```sh
git remote set-url origin git@github.com:bulicmatko/dotfiles.git
```
