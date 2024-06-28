#! /bin/env bash

# Script to create tags and add external repository to existing Koji instance

TAG=$1
BUILD_TAG="$TAG"-build
RPM_ARCH=''

set -e

if [[ "$#" -lt 1 ]]; then
    echo "Required tag name as argument! Aborting"
    exit
fi

if [[ "$RPM_ARCH" = '' ]]; then
    echo "RPM Architecture not defined! Aborting"
    exit
fi

if [[ ! -f $PWD/parameters.sh ]];then
    echo "Config parameters absent! Aborting"
    exit
fi
source $PWD/parameters.sh

if [[ "$EUID" != 0 ]]
then 
    echo "${MAGENTA}Please run with administrator privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi


# Check connectivity
if ! timeout 5s sudo -u kojiadmin koji moshimoshi; then
    echo "${MAGENTA}Koji Hub took too long to respond! Aborting...${NORMAL}"
    exit
fi

# Add a tag
sudo -u kojiadmin koji add-tag "$TAG" --arches "$RPM_ARCH"

# Add another tag that inherits from previous tag. This will serve as our build tag
sudo -u kojiadmin koji add-tag --parent "$TAG" --arches "$RPM_ARCH" "$BUILD_TAG"

# Create target
sudo -u kojiadmin koji add-target "$TAG" "$BUILD_TAG" "$TAG"

# Add groups

# build group
sudo -u kojiadmin koji add-group "$BUILD_TAG" build

sudo -u kojiadmin koji add-group-pkg "$BUILD_TAG" build \
bash \
bzip2 \
coreutils \
cpio \
diffutils \
fedora-release \
findutils \
gawk \
glibc-minimal-langpack \
grep \
gzip \
info \
make \
patch \
redhat-rpm-config \
rpm-build \
sed \
shadow-utils \
tar \
unzip \
util-linux \
which \
xz

# srpm-build group
sudo -u kojiadmin koji add-group "$BUILD_TAG" srpm-build

sudo -u kojiadmin koji add-group-pkg "$BUILD_TAG" srpm-build \
bash \
fedora-release \
fedpkg-minimal \
glibc-minimal-langpack \
gnupg2 \
redhat-rpm-config \
rpm-build \
shadow-utils

echo "${GREEN}Complete.${NORMAL}"


# EOF







