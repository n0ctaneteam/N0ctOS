#!/bin/env bash

# install base packages
notify(){
    echo -e "\x1b[32;1;4m====== $@ ======"
}

# update system
notify Updating System
sudo pacman -Syyu --noconfirm --color --quiet

# git, base-devel
notify "Checking Git & Base-devel"
sudo pacman -S git base-devel --noconfirm --color --needed --quiet
notify "Git & Base-devel Installed"

# install yay
if command -v yay &> /dev/null; then
    notify "yay is installed."
else
    notify "Installing Yay"
    git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si
    notify "YAY is installed !!!"
fi


# install paru
if command -v paru &> /dev/null; then
    notify "PARU is installed."
else
    notify "Installing Paru"
    git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si
    notify "Paru is installed !!!"
fi

