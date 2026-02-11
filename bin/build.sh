#!/bin/env bash

# this script helps to copy the bin files from dev folder to /usr/local/bin
# make sure to chown the /usr/local/bin path, or else it wont work

# set your dev folder in which the scripts stay. This will copy every child(folders too)
DEV_SCRIPTS_PATH="the/path/to/scripts"

find "$DEV_SCRIPTS_PATH"/ -type f \
    \( -name "*.sh" -o ! -name "*.*" \) \
  -exec chmod +x {} +

rm /usr/local/bin/* -rf

cp "$DEV_SCRIPTS_PATH"/* /usr/local/bin/ -r

tree -a /usr/local/bin/
