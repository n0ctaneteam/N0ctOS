# !/bin/bash
set -e
clear
echo -e "\n\n\\e[32m=== Installing N0ctBar... ===\\e[0m"
# refresh package lists
echo -e "\n> Refreshing repos..."
yay -Sy
# install dependencies
echo -e "\n> Installing Dependencies..."

yay -S runapp aylurs-gtk-shell-git --noconfirm --needed --quiet 
sudo pacman -S waybar --noconfirm --needed --quiet

echo -e "\n\n\\e[32m!!! Dependencies installed successfully !!!\\e[0m"

# copy dotfiles
echo -e "\n> Copying dotfiles..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cp -rf "$DIR"/* ~/.config/N0ctBar2/
chmod +x ~/.config/N0ctBar2/launch.sh

chmod +x ~/.config/N0ctBar2/n0ctbar
chmod +x ~/.config/N0ctBar/n0ctbar

echo -e "\n\n\\e[32m!!! Dotfiles copied successfully !!!\\e[0m"

# remove files
echo -e "\n> Removing uneccessary files..."
rm -f ~/.config/N0ctBar2/install.sh

# add binary to path
echo -e "\n> Adding binary to path..."

sudo cp -f "$DIR/n0ctbar" /usr/bin/n0ctbar
rm -rf ~/.config/N0ctBar2/n0ctbar
sudo chmod +x /usr/bin/n0ctbar
clear
echo -e "\n\n\\e[32m=== !!! Installation Complete !!! ===\\e[0m"