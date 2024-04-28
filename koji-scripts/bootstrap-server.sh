#! /bin/env bash

# Script to create tags and add external repository to existing Koji instance

TAG=q8
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

# Add tags
sudo -u kojiadmin koji add-tag build-modules
sudo -u kojiadmin koji add-tag dist-qingsong8
sudo -u kojiadmin koji add-tag dist-qingsong8-build
sudo -u kojiadmin koji add-tag dist-qingsong8-compose
sudo -u kojiadmin koji add-tag dist-qingsong8-updates
sudo -u kojiadmin koji add-tag dist-qingsong8-updates-build
sudo -u kojiadmin koji add-tag dist-qingsong8_9-updates-build
sudo -u kojiadmin koji add-tag el8
sudo -u kojiadmin koji add-tag trash
sudo -u kojiadmin koji add-tag trashcan

# Setup dist-qingsong8-build
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-build el8 --priority 10
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-build dist-qingsong8 --priority 20
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-build build-modules --priority 30

# Setup dist-qingsong8-updates-build
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-updates-build el8 --priority 10
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-updates-build dist-qingsong8-updates --priority 20
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-updates-build dist-qingsong8-build --priority 30

# Setup qingsong8-updates
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8-updates dist-qingsong8 --priority 10

# Setup dist-qingsong8_9-updates-build
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8_9-updates-build el8 --priority 10
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8_9-updates-build dist-qingsong8-updates --priority 20
sudo -u kojiadmin koji add-tag-inheritance dist-qingsong8_9-updates-build dist-qingsong8-build --priority 30

# Set Build Target Arch
sudo -u kojiadmin koji edit-tag --arches 'i686 x86_64' dist-qingsong8-build
sudo -u kojiadmin koji edit-tag --arches 'i686 x86_64' dist-qingsong8-updates-build
sudo -u kojiadmin koji edit-tag --arches 'i686 x86_64' dist-qingsong8_9-updates-build
sudo -u kojiadmin koji edit-tag --arches 'i686 x86_64' dist-qingsong8-build

# Add another tag that inherits from previous tag. This will serve as our build tag
sudo -u kojiadmin koji add-tag --parent "$TAG" --arches "$RPM_ARCH" "$BUILD_TAG"

# The build tag is what is used as the buildroot for building packages

# Create target
sudo -u kojiadmin koji add-target dist-qingsong8 dist-qingsong8-build dist-qingsong8 
sudo -u kojiadmin koji add-target dist-qingsong8-updates dist-qingsong8-updates-build dist-qingsong8-updates 
sudo -u kojiadmin koji add-target dist-qingsong8_9-updates dist-qingsong8_9-updates-build dist-qingsong8 

# Add build groups
sudo -u kojiadmin koji add-group dist-qingsong8-build build
sudo -u kojiadmin koji add-group dist-qingsong8-updates-build build
sudo -u kojiadmin koji add-group dist-qingsong8_9-updates-build build

#  Add 'build' group pkgs
sudo -u kojiadmin koji add-group-pkg  dist-qingsong8-build build \
bash \
buildsys-macros-el8 \
bzip2 \
coreutils \
cpio \
diffutils \
findutils \
gawk \
gcc \
gcc-c++ \
git \
grep \
gzip \
info \
make \
patch \
qingsong-release \
redhat-rpm-config \
rpm-build \
scl-utils-build \
sed \
shadow-utils \
tar \
unzip \
util-linux \
which \
xz \
module-build-macro \
getsrc

sudo -u kojiadmin koji add-group-pkg  dist-qingsong8-updates-build build \
bash \
buildsys-macros-el8 \
bzip2 \
coreutils \
cpio \
diffutils \
findutils \
gawk \
gcc \
gcc-c++ \
git \
grep \
gzip \
info \
make \
patch \
qingsong-release \
redhat-rpm-config \
rpm-build \
scl-utils-build \
sed \
shadow-utils \
tar \
unzip \
util-linux \
which \
xz \
module-build-macro \
getsrc

sudo -u kojiadmin koji add-group-pkg  dist-qingsong8_9-updates-build build \
bash \
buildsys-macros-el8 \
bzip2 \
coreutils \
cpio \
diffutils \
findutils \
gawk \
gcc \
gcc-c++ \
git \
grep \
gzip \
info \
make \
patch \
qingsong-release \
redhat-rpm-config \
rpm-build \
scl-utils-build \
sed \
shadow-utils \
tar \
unzip \
util-linux \
which \
xz \
module-build-macro \
getsrc

# srpm-build group
sudo -u kojiadmin koji add-group  dist-qingsong8-build srpm-build
sudo -u kojiadmin koji add-group  dist-qingsong8-updates-build srpm-build
sudo -u kojiadmin koji add-group  dist-qingsong8_9-updates-build srpm-build

sudo -u kojiadmin koji add-group-pkg dist-qingsong8-build srpm-build \
bash \
buildsys-macros-el8 \
git \
qingsong-release \
redhat-rpm-config \
rpm-build \
shadow-utils \
scl-utils-build \
shadow-utils \
system-release \
getsrc

sudo -u kojiadmin koji add-group-pkg dist-qingsong8-updates-build srpm-build \
bash \
buildsys-macros-el8 \
git \
qingsong-release \
redhat-rpm-config \
rpm-build \
shadow-utils \
scl-utils-build \
shadow-utils \
system-release \
getsrc

sudo -u kojiadmin koji add-group-pkg dist-qingsong8_9-updates-build srpm-build \
bash \
buildsys-macros-el8 \
git \
qingsong-release \
redhat-rpm-config \
rpm-build \
shadow-utils \
scl-utils-build \
shadow-utils \
system-release \
getsrc

sudo -u kojiadmin koji add-external-repo -t dist-qingsong8-build rocky-8-bootstrap https://koji.rockylinux.org/kojifiles/repos/dist-rocky8-build/latest/\$arch -m bare

echo "${GREEN}
-------------------------
Server Bootstrap Complete
-------------------------
${NORMAL}"


# EOF
