#! /bin/env bash

# Script to Add new users to existing Koji instance

set -e

KOJI_USER=$1

if [[ "$#" < 1 ]];then
    echo "Please provide username as argument!"
    exit
fi

if [[ ! -f $PWD/parameters.sh ]];then
    echo "ERROR! Config parameters absent."
    exit
fi

source $PWD/parameters.sh

if [[ ! -f "$KOJI_PKI_DIR"/gen-certs.sh ]];then
    echo "${MAGENTA}Certificate generation script absent in Koji PKI directory. Aborting${NORMAL}"
    exit
fi

# Check if running as root
if [[ "$EUID" != 0 ]];then 
    echo "${MAGENTA}Please run with administrative privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi

# Add user to Koji database and grant admin permission
sudo -u kojiadmin koji add-user "$KOJI_USER"
sudo -u kojiadmin koji grant-permission --new admin "$KOJI_USER"


# Generate user certificates
pushd "$KOJI_PKI_DIR"
./gen-certs.sh "$KOJI_USER"
popd

mkdir "$KOJI_USER"-certs
cp "$KOJI_PKI_DIR"/"$KOJI_USER".pem "$KOJI_PKI_DIR"/koji_ca_cert.crt "$KOJI_USER"-certs







