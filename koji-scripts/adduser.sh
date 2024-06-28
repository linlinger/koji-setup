#! /bin/env bash

# Script to Add new users to existing Koji instance
# To be executed on host running Koji server

set -e

KOJI_USER=$1

if [[ "$#" -lt 1 ]]; then
    echo "Please provide username as argument!"
    exit
fi

if [[ ! -f "$PWD"/parameters.sh ]]; then
    echo "ERROR! Config parameters absent."
    exit
fi

source "$PWD"/parameters.sh

if [[ ! -f "$KOJI_PKI_DIR"/gen-certs.sh ]]; then
    echo "${MAGENTA}Could not find certificate generator script in $KOJI_PKI_DIR.. Aborting${NORMAL}"
    exit
fi

# Check if running as root
if [[ "$EUID" != 0 ]]; then 
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

if [[ "$USER" = root ]] && [[ ! -d /home/root/.koji ]]; then
    KOJI_CONFIG_DIR=/home/root/.koji
elif [[ ! -d /home/$SUDO_USER/.koji ]]; then
    echo "Koji configuration missing, do you wish to create config for current user ${CYAN}$SUDO_USER${NORMAL} (Y/n) : "
    read -r input 

    if [[ $input =~ ^(y|Y)$ ]];  then
        KOJI_CONFIG_DIR=/home/$SUDO_USER/.koji
    else
        KOJI_CONFIG_DIR=/etc/pki/koji/users/$KOJI_USER
    fi
fi

mkdir -p "$KOJI_CONFIG_DIR"
cp "$KOJI_PKI_DIR"/"$KOJI_USER".pem "$KOJI_CONFIG_DIR"
cp "$KOJI_PKI_DIR"/koji_ca_cert.crt "$KOJI_CONFIG_DIR"
cat > "$KOJI_CONFIG_DIR"/config <<- EOF
[koji]
server = $KOJI_URL/kojihub
weburl = $KOJI_URL/koji
topurl = $KOJI_URL/kojifiles
topdir = $KOJI_URL/kojifiles
authtype = ssl
cert = $KOJI_CONFIG_DIR/$KOJI_USER.pem
serverca = $KOJI_CONFIG_DIR/koji_ca_cert.crt
anon_retry = true
EOF


echo "Generated certificates in $KOJI_CONFIG_DIR"
echo "${GREEN}Complete${NORMAL}"







