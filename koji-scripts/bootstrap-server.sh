#! /bin/env bash

# Script to create tags and add external repository to existing Koji instance

TAG=f38
BUILD_TAG="$TAG"-build
RPM_ARCH='riscv64'

set -e

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

# The build tag is what is used as the buildroot for building packages

# Add external repo to the build tag (optional)
# sudo -u kojiadmin koji add-external-repo -t "$BUILD_TAG" <repo-name> <repo-url>

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

echo "${GREEN}
-------------------------
Server Bootstrap Complete
-------------------------
${NORMAL}"


# EOF
