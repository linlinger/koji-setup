#!/bin/env bash

# Script to be run on Koji Builder
# Execute addbuilder.sh first on koji server to add builder to database and generate certificates
# Finally copy this script along with certificates to builder
# Fill in KOJI_BUILDER_FQDN and KOJI_URL before executing

set -e

MAGENTA=$(tput setaf 5)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

KOJI_BUILDER_FQDN=""
KOJI_URL=""
KOJI_PKI_DIR=/etc/pki/koji

if [[ "$KOJI_BUILDER_FQDN" = "" ]]; then
    echo "${MAGENTA}Error! Builder Name not specified!${NORMAL}"
elif [[ "$KOJI_URL" = "" ]]; then
    echo "${MAGENTA}Error! Koji URL not specified!${NORMAL}"
fi

# Copy certificates to PKI directory
if [[ ! $(ls "$PWD"/*.pem) ]] && [[ ! $(ls "$PWD"/*crt) ]];then
    echo "${MAGENTA}Could not find certificates in $PWD...Aborting.${NORMAL}"
    exit 1
else
    mkdir -p  "$KOJI_PKI_DIR"
    cp "$PWD"/*.pem "$PWD"/*.crt "$KOJI_PKI_DIR"
fi

# Create mock directories and permissions
mkdir -p /etc/mock/koji
mkdir -p /var/lib/mock
chown -R root:mock /var/lib/mock

# Setup User Accounts
usermod -G mock kojibuilder

mkdir -p /etc/kojid
cat > /etc/kojid/kojid.conf <<- EOF
[kojid]
sleeptime=5
maxjobs=1
topdir=/mnt/koji
workdir=/tmp/koji
mockdir=/var/lib/mock
mockuser=kojibuilder
mockhost=generic-linux-gnu
user=$KOJI_BUILDER_FQDN
server=$KOJI_URL/kojihub
topurl=$KOJI_URL/kojifiles
use_createrepo_c=True
rpmbuild_timeout=864000
allowed_scms=
    !src.fedoraproject.org:/pagure/fork/*
    !src.fedoraproject.org:/pagure/forks/*
    !pkgs.fedoraproject.org:/pagure/fork/*
    !pkgs.fedoraproject.org:/pagure/forks/*
    !src.fedoraproject.org:/fork/*
    !src.fedoraproject.org:/forks/*
    !src.fedoraproject.org:/cgit/*
    !src.fedoraproject.org:/git/*
    !pkgs.fedoraproject.org:/fork/*
    !pkgs.fedoraproject.org:/forks/*
    !pkgs.fedoraproject.org:/cgit/*
    !pkgs.fedoraproject.org:/git/*
    pkgs.fedoraproject.org:/*:false:fedpkg,sources
    pagure.io:/fedora-kickstarts.git:false
    src.fedoraproject.org:/*:false:fedpkg,sources
    pagure.io:/fork/*/fedora-kickstarts.git:false
cert = $KOJI_PKI_DIR/$KOJI_BUILDER_FQDN.pem
serverca = $KOJI_PKI_DIR/koji_ca_cert.crt
EOF

systemctl enable --now kojid

echo "${GREEN}Successfully started builder!{$NORMAL}"

#EOF