#!/usr/bin/env bash
#
# macOS system settings — applied with `defaults write` so a new Mac never
# needs a manual tour through System Settings and Finder preferences.
#
# Values were harvested from a configured machine (2026-08), so running this
# reproduces that setup. Runs standalone or as part of os/macos/install.sh:
#
#   ./os/macos/defaults.sh
#
# Some changes need a logout/restart to fully apply; Dock and Finder are
# restarted automatically at the end.

set -euo pipefail

[ "$(uname -s)" = "Darwin" ] || { echo "macOS only" >&2; exit 1; }

# Close System Settings so it does not clobber the values written below.
osascript -e 'tell application "System Settings" to quit' &>/dev/null || true
osascript -e 'tell application "System Preferences" to quit' &>/dev/null || true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# General UI
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Show all filename extensions everywhere
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Show scroll bars only when scrolling
defaults write NSGlobalDomain AppleShowScrollBars -string "WhenScrolling"

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Keyboard & text input
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Fast key repeat with a short initial delay
defaults write NSGlobalDomain KeyRepeat -int 5
defaults write NSGlobalDomain InitialKeyRepeat -int 30

# No automatic capitalization, spelling correction, or period substitution
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Keyboard navigation: Tab moves focus between all controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Trackpad
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Tap to click (built-in, bluetooth, and current host)
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Finder
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true

# List view by default
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Search the current folder, not the whole Mac
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# New Finder windows open the home folder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME/"

# Desktop shows external and removable drives, but not internal ones
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false

# The sidebar keeps its stock favorites — Desktop, Documents, Downloads, and
# Applications — which is what a Mac ships with, so there is nothing to set.

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Spotlight
#
# Spotlight as a launcher rather than a search engine: apps, the calculator,
# System Settings panes, and code stay on, and every category that turns a
# keystroke into a list of documents, mail, and web suggestions stays off.
#
# The order below is the order Spotlight lists the categories in, and the
# whole array is written at once because that is how the preference is
# stored — leaving one out drops it from the results entirely.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

spotlight_items=()
while IFS='|' read -r item_name item_enabled; do
  [ -n "$item_name" ] || continue
  spotlight_items[${#spotlight_items[@]}]="<dict><key>enabled</key><$item_enabled/><key>name</key><string>$item_name</string></dict>"
done <<'EOF'
APPLICATIONS|true
MENU_EXPRESSION|true
CONTACT|false
MENU_CONVERSION|false
MENU_DEFINITION|false
DOCUMENTS|false
EVENT_TODO|false
DIRECTORIES|false
FONTS|false
IMAGES|false
MESSAGES|false
MOVIES|false
MUSIC|false
MENU_OTHER|false
PDF|false
PRESENTATIONS|false
MENU_SPOTLIGHT_SUGGESTIONS|false
SPREADSHEETS|false
SYSTEM_PREFS|true
TIPS|false
BOOKMARKS|false
SOURCE|true
EOF
defaults write com.apple.Spotlight orderedItems -array "${spotlight_items[@]}"

# Clipboard history, kept for half an hour.
defaults write com.apple.Spotlight PasteboardHistoryEnabled -bool true
defaults write com.apple.Spotlight PasteboardHistoryTimeout -int 1800

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Screensaver
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Start after 10 minutes idle, show the clock over it
defaults -currentHost write com.apple.screensaver idleTime -int 600
defaults -currentHost write com.apple.screensaver showClock -bool true

# The screen saver is Drift, its appearance following the system, tinted with
# the same #1f2335 the editors and terminal use.
#
# Current macOS keeps that choice and its options in a binary store `defaults`
# cannot reach, so the configuration harvested from a working machine is
# written into the store as-is and WallpaperAgent restarted to load it. The
# moduleDict below carries the same choice for the older releases that read it.
defaults -currentHost write com.apple.screensaver moduleDict '<dict><key>moduleName</key><string>Drift</string><key>path</key><string>/System/Library/ExtensionKit/Extensions/Drift.appex</string><key>type</key><integer>0</integer></dict>'

WALLPAPER_STORE="$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
# Drift, as file:///System/Library/ExtensionKit/Extensions/Drift.appex
SCREENSAVER_MODULE='YnBsaXN0MDDRAQJWbW9kdWxl0QMEWHJlbGF0aXZlXxA6ZmlsZTovLy9TeXN0ZW0vTGlicmFyeS9FeHRlbnNpb25LaXQvRXh0ZW5zaW9ucy9EcmlmdC5hcHBleAgLEhUeAAAAAAAAAQEAAAAAAAAABQAAAAAAAAAAAAAAAAAAAFs='
# Its options: automatic appearance + the custom tint color
SCREENSAVER_OPTIONS='YnBsaXN0MDDRAQJWdmFsdWVz0wMEBQYNGlphcHBlYXJhbmNlW2N1c3RvbUNvbG9yXxAgbGVnYWN5U2NyZWVuU2F2ZXJHZW5lcmF0aW9uQ291bnTRBwhWcGlja2Vy0QkKUl8w0QsMUmlkWWF1dG9tYXRpY9EOD1Vjb2xvctEJENEOEdISExQZWmNvbXBvbmVudHNaY29sb3JTcGFjZaQVFhcYIz+/mCEf0oa1Iz/BmFJ/6T8qIz/J7JxABg0yIz/wAAAAAAAATxArYnBsaXN0MDAQBwgAAAAAAAABAQAAAAAAAAABAAAAAAAAAAAAAAAAAAAACtEHG9EJHNELHVEyCAsSGSQwU1ZdYGNmaXN2fH+Ch5Kdoqu0vcb09/r9AAAAAAAAAQEAAAAAAAAAHgAAAAAAAAAAAAAAAAAAAP8='

if [ -f "$WALLPAPER_STORE" ] && plutil -extract \
  'AllSpacesAndDisplays.Idle.Content.Choices.0.Configuration' raw "$WALLPAPER_STORE" >/dev/null 2>&1; then
  # Skip the rewrite (and the restart) when the screen saver already matches.
  if [ "$(plutil -extract 'AllSpacesAndDisplays.Idle.Content.Choices.0.Configuration' raw "$WALLPAPER_STORE" 2>/dev/null)" != "$SCREENSAVER_MODULE" ]; then
    cp "$WALLPAPER_STORE" "$WALLPAPER_STORE.backup.$(date +%Y%m%d%H%M%S)"
    plutil -replace 'AllSpacesAndDisplays.Idle.Content.Choices.0.Configuration' \
      -data "$SCREENSAVER_MODULE" "$WALLPAPER_STORE"
    plutil -replace 'AllSpacesAndDisplays.Idle.Content.EncodedOptionValues' \
      -data "$SCREENSAVER_OPTIONS" "$WALLPAPER_STORE"
    killall WallpaperAgent >/dev/null 2>&1 || true
  fi
else
  echo "screen saver store not found — pick a screen saver once in System Settings, then re-run" >&2
fi

# Require the password 5 seconds after the screensaver starts. sysadminctl
# prompts for your account password, so run it manually once per machine:
#   sysadminctl -screenLock 5 -password -

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Dock
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Auto-hide the Dock, small fixed tiles, no magnification
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock tilesize -int 42
defaults write com.apple.dock magnification -bool false
defaults write com.apple.dock largesize -int 16

# No recent apps section; minimize into a separate Dock slot
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock minimize-to-application -bool false

# Hot corners disabled (bottom-right explicitly off)
defaults write com.apple.dock wvous-br-corner -int 1

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Opt-ins — not part of the harvested setup, uncomment if wanted
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

# Expand the save and print dialogs by default
# defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
# defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
# defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
# defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# Save to disk (not iCloud) by default
# defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Stop littering .DS_Store on network shares and USB drives
# defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
# defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Screenshots: save to ~/Screenshots as png without window shadows
# mkdir -p "$HOME/Screenshots"
# defaults write com.apple.screencapture location -string "$HOME/Screenshots"
# defaults write com.apple.screencapture type -string "png"
# defaults write com.apple.screencapture disable-shadow -bool true

# Finder: show path bar and status bar
# defaults write com.apple.finder ShowPathbar -bool true
# defaults write com.apple.finder ShowStatusBar -bool true

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Apply
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

for app in Dock Finder SystemUIServer Spotlight; do
  killall "$app" &>/dev/null || true
done

echo "macOS defaults applied — some changes need a logout/restart to take effect"
