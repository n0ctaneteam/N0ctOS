#!/bin/env bash

# if (( "$ISO_MODE" == true )); then
# 	exit 0
# fi


# here we install additional pkgs that aren't available on pacman/AUR repos

# install oh-my-posh (shell prompt)
# config will be loaded in [3.2-configs.sh]
curl -s https://ohmyposh.dev/install.sh | bash -s