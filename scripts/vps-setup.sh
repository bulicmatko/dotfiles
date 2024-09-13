# Update package list
apt update

# Upgrade packages
apt upgrade -y

# Update package list once again
apt update

# Upgrade packages once again
apt upgrade -y

# List upgradable packages
apt list --upgradable

# Install upgradable packages
apt install <upgradable-packages>

# Install keychain
apt install keychain

# Instal zsh
apt install zsh -y

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

# Symlink .ssh/config
mv ~/.ssh/config ~/.ssh/config.backup
ln -s $(pwd)/templates/.ssh/config ~/.ssh/config

# Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash

# Set zsh as default shell
# chsh -s $(which zsh)
