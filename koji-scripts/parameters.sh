#!/bin/env bash

# Parameters to be used by various Koji components

## Colors, requires ncurses
export RED=$(tput setaf 1)
export GREEN=$(tput setaf 2)
export YELLOW=$(tput setaf 3)
export BLUE=$(tput setaf 4)
export MAGENTA=$(tput setaf 5)
export CYAN=$(tput setaf 6)
export NORMAL=$(tput sgr0)

## KOJI RPM BUILD AND TRACKER
export KOJI_DIR=/mnt/koji
export KOJI_MOUNT_DIR="$KOJI_DIR"
export KOJI_PKI_DIR=/etc/pki/koji

export KOJI_SERVER_FQDN="$(hostname -f)"
# Comment the line above and uncomment the one below to use IP address instead
#export KOJI_SERVER_FQDN="$(ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}')"

export KOJI_BUILDER_FQDN="$KOJI_SERVER_FQDN"
export KOJI_URL=http://"$KOJI_SERVER_FQDN"
export KOJID_CAPACITY=16

# Used for koji SSL certificates
export COUNTRY_CODE='NA'
export STATE='Example'
export LOCATION='Example'
export ORGANIZATION='Example'
export ORG_UNIT='Example'


## POSTGRESQL DATABASE
export POSTGRES_USER=postgres
export POSTGRES_DEFAULT_DIR=/var/lib/pgsql

## APACHE 
export HTTPD_USER=apache
export HTTPD_DOCUMENT_ROOT=/var/www/html

#EOF