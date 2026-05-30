#!/bin/env bash


# if (( "$ISO_MODE" == true )); then
# 	exit 0
# fi

# install base packages
# update system
notify installing Git, Yay, Paru
sudo pacman -Syy --noconfirm

# git, base-devel
info "Checking Git & Base-devel"
sudo pacman -S git base-devel --noconfirm --needed
info "Git & Base-devel Installed"

# install yay
if command -v yay &> /dev/null; then
    info "yay is installed."
else
    info "Installing Yay"
    cd
    git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si
    info "YAY is installed !!!"
fi


# install paru
if command -v paru &> /dev/null; then
    info "PARU is installed."
else
    info "Installing Paru"
    cd
    git clone https://aur.archlinux.org/paru.git && cd paru && makepkg -si
    info "Paru is installed !!!"
fi

