#! /bin/env bash

# Script to Add new Builders to existing Koji instance

set -e

KOJI_BUILDER=$1

if [[ "$#" -lt 1 ]]; then
    echo "Please provide builder name or FQDN as argument!"
    exit
fi

if [[ ! -f "$PWD"/parameters.sh ]]; then
    echo "ERROR! Config parameters absent."
    exit
fi

source "$PWD"/parameters.sh

if [[ ! -f "$KOJI_PKI_DIR"/gen-certs.sh ]]; then
    echo "${MAGENTA}Could not find certificate generator script in /etc/pki/koji. Aborting${NORMAL}"
    exit
fi

# Check if running as root
if [[ "$EUID" != 0 ]];then 
    echo "${MAGENTA}Please run with administrative privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi

# Add builder to Koji database
sudo -u kojiadmin koji add-host "$KOJI_BUILDER" "$RPM_ARCH"
koji edit-host --capacity=1.5 "$KOJI_BUILDER"


# Generate builder certificates
pushd "$KOJI_PKI_DIR"
./gen-certs.sh "$KOJI_BUILDER"
popd

mkdir "$KOJI_BUILDER"-certs
cp "$KOJI_PKI_DIR"/"$KOJI_BUILDER".pem "$KOJI_PKI_DIR"/koji_ca_cert.crt "$KOJI_BUILDER"-certs







