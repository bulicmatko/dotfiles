# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Spacehip Theme
git clone https://github.com/spaceship-prompt/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Install zsh-nvm
git clone https://github.com/lukechilds/zsh-nvm "$ZSH_CUSTOM/plugins/zsh-nvm"

# Install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"

# Symlink .zshrc
mv ~/.zshrc ~/.zshrc.backup
ln -s $(pwd)/.zshrc ~/.zshrc

# Symlink .gitconfig
mv ~/.gitconfig ~/.gitconfig.backup
ln -s $(pwd)/.gitconfig ~/.gitconfig

# Install Homebrew Packages
brew install nvm

# Install Homebrew Casks
brew install --cask visual-studio-code
brew install --cask warp
brew install --cask moom
brew install --cask google-chrome
brew install --cask 1password

