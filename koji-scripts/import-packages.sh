#! /bin/env bash

# Import existing rpm packages to koji and tag them
# Requires user executing the script to have created user in database and generated certificates
# Recommended to execute adduser.sh script first

set -e

if [[ "$#" -lt 2 ]]; then
    echo "Required directory path as argument and tag name as arguments!"
    echo "Usage : $0 <dir_path> <tag_name>"
    echo "Exiting..."
    exit
fi

if [[ "$EUID" != 0 ]]
then 
    echo "${MAGENTA}Please run with administrator privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi


# Check connectivity
if ! timeout 5s koji moshimoshi; then
    echo "${MAGENTA}Failed to establish connection with koji server! Aborting...${NORMAL}"
    exit
fi


PKG_DIR=$1
TAG=$2

# Import rpm packages recursively from specified directory
sudo -u "$SUDO_USER" find "$PKG_DIR" -iname "*.rpm" | xargs koji import --create-build

# Add package names to tag
sudo -u "$SUDO_USER" koji list-pkgs --quiet | xargs koji add-pkg --owner kojiadmin "$TAG"

# Tag imported packages under specified tag
sudo -u "$SUDO_USER" koji list-untagged | xargs -n 1 koji call tagBuildBypass "$TAG"

