# IMPORTANT NOTE!!!
# This install script is used for Github Codespaces

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Install Spacehip Theme
git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt" --depth=1
ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"

# Install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Use zsh
chsh -s $(which zsh)

# Symlink oh-my-zsh
mv ~/.zshrc ~/.zshrc.backup
ln -s $(pwd)/.zshrc ~/.zshrc

# Symlink gitconfig
mv ~/.gitconfig ~/.gitconfig.backup
ln -s $(pwd)/.gitconfig ~/.gitconfig
