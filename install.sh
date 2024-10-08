# IMPORTANT NOTE!
# This install script is used for Github Codespaces

# Prepare
sudo apt update
sudo apt upgrade -y
sudo apt install keychain
sudp apt install zsh -y

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
ln -s $(pwd)/templates/.zshrc ~/.zshrc

# Symlink .gitconfig
mv ~/.gitconfig ~/.gitconfig.backup
ln -s $(pwd)/templates/.gitconfig ~/.gitconfig

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Set zsh as default shell
# chsh -s $(which zsh)
