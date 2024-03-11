#! /bin/env bash

# Script to generate SSL certificates 

set -e

if [[ ! -f $PWD/parameters.sh ]];then
    echo "ERROR! Config parameters absent."
    exit
fi

if [[ "$EUID" != 0 ]]
then 
    echo "${MAGENTA}Please run with administrator privileges!{$NORMAL}"
    echo "Try sudo $0"
    exit
fi

source $PWD/parameters.sh

KOJI_USER=$1
COMMON_NAME=$2

if [[ "$#" -lt 1 ]]; then
    echo "${MAGENTA}ERROR! Too few arguments!${NORMAL}"
    exit
elif [[ "$#" -eq 1 ]]; then
    COMMON_NAME=$1
fi

# Generate private key for the user/component
openssl genrsa -out private/"$KOJI_USER".key 4096

openssl req -config ssl.cnf -new -nodes -out certs/"$KOJI_USER".csr -key private/"$KOJI_USER".key \
-subj "/C=$COUNTRY_CODE/ST=$STATE/L=$LOCATION/O=$ORGANIZATION/OU="$KOJI_USER"/CN=${COMMON_NAME}"

# Sign CSRs with CA certificate to generate certificates
openssl ca -batch -config ssl.cnf -keyfile private/koji_ca_cert.key -cert koji_ca_cert.crt \
-out certs/"$KOJI_USER".crt -outdir certs -infiles certs/"$KOJI_USER".csr

# Concatenate key and cert file into a single PEM file
cat certs/"$KOJI_USER".crt private/"$KOJI_USER".key > "$KOJI_USER".pem

# Generate PKCK12 certificate for browser

openssl pkcs12 -export -inkey private/"$KOJI_USER".key -in certs/"$KOJI_USER".crt \
-CAfile koji_ca_cert.crt -out certs/"$KOJI_USER"_browser_cert.p12 -passout pass:

#EOF
