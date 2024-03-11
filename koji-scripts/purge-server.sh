#! /bin/env bash

# Script to remove Koji components from system

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
NORMAL=$(tput sgr0)

# Check if running as root
if [[ "$EUID" != 0 ]];then 
    echo "${MAGENTA}Please run with administrator privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi

printf "This will remove the following packages and their dependencies :
${RED}koji 
koji-hub 
koji-web 
koji-utils 
koji-builder
httpd
postgresql ${NORMAL}

${MAGENTA}All configuration files associated with these packages will also be removed.
Make sure you have made a backup before proceeding!${NORMAL}

${YELLOW}Do you wish to continue ? (y/N) :${NORMAL}"
read input

if [[ $input =~ ^(y|Y)$ ]]; then

    if [[ ! -f $PWD/parameters.sh ]];then
        printf "${MAGENTA}Could not find parameters.sh! Aborting...${NORMAL}"
        exit
    fi
    source parameters.sh

    dnf remove -y koji koji-hub mod_ssl koji-web koji-builder koji-utils \
    postgresql-server httpd

    for datadir in "$KOJI_PKI_DIR" "$KOJI_MOUNT_DIR" "$POSTGRES_DEFAULT_DIR";do
        rm -rf $datadir 
    done

    if id kojiadmin &>/dev/null; then
        userdel -r kojiadmin
    fi

    if id koji &>/dev/null; then
        userdel koji
    fi

    KOJIRA_SYSTEMD_FILE=/etc/systemd/system/kojira.service.d/after-postgresql.conf
    if [[ -f $KOJIRA_SYSTEMD_FILE ]];then
        rm $KOJIRA_SYSTEMD_FILE
    fi

    # Revert SELinux flags and file contexts
    SELINUX_STATUS=$(getenforce)

    if [[ "$SELINUX_STATUS" != "Disabled" ]];then
        setsebool -P allow_httpd_anon_write=0
        setsebool -P httpd_can_network_connect=0 
    fi

else
    echo "Exiting..."
    exit 1
fi

#EOF




