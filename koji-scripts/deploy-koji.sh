#! /bin/env bash

# Script to deploy Koji Server 

set -e

NATIVE_ARCH=$(uname -m)

if [[ ! -f "parameters.sh" ]] && [[ ! -f "gen-certs.sh" ]]
then
    echo "ERROR! Config parameters absent"
    exit
fi

source $PWD/parameters.sh

# Check if running as root
if [[ "$EUID" != 0 ]]
then 
    echo "${MAGENTA}Please run with administrator privileges!${NORMAL}"
    echo "Try sudo $0"
    exit
fi

# Check if nodocs is set in dnf configuration (common in containers)
dnf_conf="/etc/dnf/dnf.conf"

if [ -e "$dnf_conf" ]; then
    # Check if the line tsflags=nodocs is present
    if grep -q "^tsflags=nodocs" "$dnf_conf"; then
        sed -i 's/^tsflags=nodocs/#&/' "$dnf_conf"
    fi
fi

# Install packages
dnf install -y koji koji-hub mod_ssl koji-web koji-builder koji-utils \
postgresql-server httpd openssl net-tools ncurses

# ------------------------------------------------------------------------------------------------------
## SETTING UP SSL CERTIFICATES FOR AUTHENTICATION
# ------------------------------------------------------------------------------------------------------

# setting up directories
mkdir -p "$KOJI_PKI_DIR"/{certs,private}
RANDFILE="$KOJI_PKI_DIR"/.rand
dd if=/dev/urandom of="$RANDFILE" bs=256 count=1

# ssl config file
cat > "$KOJI_PKI_DIR"/ssl.cnf <<- EOF
HOME                    = $KOJI_PKI_DIR
RANDFILE                = $RANDFILE

[ca]
default_ca              = ca_default

[ca_default]
dir                     = $KOJI_PKI_DIR
certs                   = \$dir/certs
crl_dir                 = \$dir/crl
database                = \$dir/index.txt
new_certs_dir           = \$dir/newcerts
certificate             = \$dir/%s_ca_cert.pem
private_key             = \$dir/private/%s_ca_key.pem
serial                  = \$dir/serial
crl                     = \$dir/crl.pem
x509_extensions         = usr_cert
name_opt                = ca_default
cert_opt                = ca_default
default_days            = 3650
default_crl_days        = 30
default_md              = sha512
preserve                = no
policy                  = policy_match

[policy_match]
countryName             = match
stateOrProvinceName     = match
organizationName        = match
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[req]
default_bits            = 4096
default_keyfile         = privkey.pem
default_md              = sha512
distinguished_name      = req_distinguished_name
attributes              = req_attributes
x509_extensions         = v3_ca # The extensions to add to the self signed cert
string_mask             = MASK:0x2002

[req_distinguished_name]
countryName                     = Country Name (2 letter code)
countryName_min                 = 2
countryName_max                 = 2
stateOrProvinceName             = State or Province Name (full name)
localityName                    = Locality Name (eg, city)
0.organizationName              = Organization Name (eg, company)
organizationalUnitName          = Organizational Unit Name (eg, section)
commonName                      = Common Name (eg, your name or your server\'s hostname)
commonName_max                  = 64
emailAddress                    = Email Address
emailAddress_max                = 64

[req_attributes]
challengePassword               = A challenge password
challengePassword_min           = 8
challengePassword_max           = 64
unstructuredName                = An optional company name

[usr_cert]
basicConstraints                = CA:FALSE
nsComment                       = "OpenSSL Generated Certificate"
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid,issuer:always

[v3_ca]
subjectKeyIdentifier            = hash
authorityKeyIdentifier          = keyid:always,issuer:always
basicConstraints                = CA:true
EOF

# generate self signed CA certificate
touch "$KOJI_PKI_DIR"/index.txt
echo 01 > "$KOJI_PKI_DIR"/serial

# Create the CA private key
openssl genrsa -out "$KOJI_PKI_DIR"/private/koji_ca_cert.key 4096

# Sign a certificate using the generated private key
openssl req -extensions v3_ca -subj "/C=$COUNTRY_CODE/ST=$STATE/L=$LOCATION/O=$ORGANIZATION/OU=Koji_CA/CN=$KOJI_SERVER_FQDN" -config "$KOJI_PKI_DIR"/ssl.cnf -new -x509 -days 3650 -key "$KOJI_PKI_DIR"/private/koji_ca_cert.key -out "$KOJI_PKI_DIR"/koji_ca_cert.crt 

# Generate component certificates

cp $PWD/gen-certs.sh "$KOJI_PKI_DIR"
cp $PWD/parameters.sh "$KOJI_PKI_DIR"
pushd "$KOJI_PKI_DIR"
./gen-certs.sh kojiweb $KOJI_SERVER_FQDN
./gen-certs.sh kojihub $KOJI_SERVER_FQDN
./gen-certs.sh kojiadmin 
./gen-certs.sh kojira 
popd


# Copy certificates for kojiadmin

useradd kojiadmin

mkdir -p /home/kojiadmin/.koji
ADMIN_KOJI_DIR="/home/kojiadmin/.koji"

cp -f "$KOJI_PKI_DIR"/kojiadmin.pem "$ADMIN_KOJI_DIR"/client.crt
cp -f "$KOJI_PKI_DIR"/koji_ca_cert.crt "$ADMIN_KOJI_DIR"/clientca.crt
cp -f "$KOJI_PKI_DIR"/koji_ca_cert.crt "$ADMIN_KOJI_DIR"/serverca.crt
chown -R kojiadmin:kojiadmin "$ADMIN_KOJI_DIR"

# ------------------------------------------------------------------------------------------------------
# POSTGRESQL SERVER SETUP
# ------------------------------------------------------------------------------------------------------

sudo -u "$POSTGRES_USER" initdb --pgdata "$POSTGRES_DEFAULT_DIR"/data
systemctl enable --now postgresql

useradd -r koji

# create new pgsql user account called koji
sudo -u "$POSTGRES_USER" createuser --no-superuser --no-createrole --no-createdb koji
# create a database called koji under the the pgsql user koji previously created
sudo -u "$POSTGRES_USER" createdb -O koji koji
# Populate the database koji with schema
sudo -u koji psql koji koji < /usr/share/koji/schema.sql

# Authorize Koji-web and Koji-hub resources
cat > "$POSTGRES_DEFAULT_DIR"/data/pg_hba.conf <<- EOF
#TYPE    DATABASE    USER       CIDR-ADDRESS    METHOD
host     koji        all        127.0.0.1/32    trust
host     koji        all        ::1/128         trust
local    koji        koji                       trust
local    all         postgres                   peer
EOF

# Increase number of connections and resources in database

sed -i '/max_connections/ s/.*/max_connections = 600/' /var/lib/pgsql/data/postgresql.conf

sed -i '/shared_buffers/ s/.*/shared_buffers = 4096MB/' /var/lib/pgsql/data/postgresql.conf

# Reload database service to apply new changes
systemctl reload postgresql

# Enable koji database cleanup service
systemctl enable --now koji-sweep-db.timer

# Bootstrapping the initial koji admin user into the PostgreSQL database
# SSL Certificate authentication
sudo -u koji psql -c "insert into users (name, status, usertype) values ('kojiadmin', 0, 0);"

# Give yourself admin permissions
sudo -u koji psql -c "insert into user_perms (user_id, perm_id, creator_id) values (1, 1, 1);"


# ------------------------------------------------------------------------------------------------------
## KOJI CONFIGURATION FILES
# ------------------------------------------------------------------------------------------------------

# Koji Hub

if [[ ! -d "/etc/httpd/conf.d" ]];then
    mkdir -p /etc/httpd/conf.d
fi

cat > /etc/httpd/conf.d/kojihub.conf <<- EOF
Alias /kojihub /usr/share/koji-hub/kojiapp.py
<Directory "/usr/share/koji-hub">
    Options ExecCGI
    SetHandler wsgi-script
    Require all granted
    WSGIApplicationGroup %{GLOBAL}
    WSGIScriptReloading Off
</Directory>

Alias /kojifiles "$KOJI_DIR"
<Directory "$KOJI_DIR">
    Options Indexes SymLinksIfOwnerMatch
    AllowOverride None
    Require all granted
</Directory>

<Location /kojihub/ssllogin>
    SSLVerifyClient require
    SSLVerifyDepth 10
    SSLOptions +StdEnvVars
</Location>
EOF

if [[ ! -d "/etc/koji-hub" ]];then
    mkdir -p /etc/koji-hub
fi

cat > /etc/koji-hub/hub.conf <<- EOF
[hub]
DBName = koji
DBUser = koji
KojiDir = $KOJI_DIR
DNUsernameComponent = CN
ProxyDNs = C=$COUNTRY_CODE,ST=$STATE,L=$LOCATION,O=$ORGANIZATION,OU=kojiweb,CN=$KOJI_SERVER_FQDN
LoginCreatesUser = On
KojiWebURL = $KOJI_URL/koji
DisableNotifications = True
EOF

# Koji Web
mkdir -p /etc/kojiweb
cat > /etc/kojiweb/web.conf <<- EOF
[web]
SiteName = koji
KojiTheme = koji-centos-theme
KojiHubURL = $KOJI_URL/kojihub
KojiFilesURL = $KOJI_URL/kojifiles
WebCert = $KOJI_PKI_DIR/kojiweb.pem
ClientCA = $KOJI_PKI_DIR/koji_ca_cert.crt
KojiHubCA = $KOJI_PKI_DIR/koji_ca_cert.crt
LoginTimeout = 72
Secret = KOJI
LibPath = /usr/share/koji-web/lib
LiteralFooter = True
EOF

cp -r koji-centos-theme /usr/share/koji-web/static/themes/

cat > /etc/httpd/conf.d/kojiweb.conf <<- EOF
Alias /koji "/usr/share/koji-web/scripts/wsgi_publisher.py"
WSGIDaemonProcess koji lang=C.UTF-8
<Directory "/usr/share/koji-web/scripts">
    Options ExecCGI
    WSGIProcessGroup koji
    WSGIApplicationGroup %{GLOBAL}
    SetHandler wsgi-script
    Require all granted
</Directory>
Alias /koji-static "/usr/share/koji-web/static"
<Directory "/usr/share/koji-web/static">
    Options None
    AllowOverride None
    Require all granted
</Directory>
EOF



# Koji CLI
cat > "$ADMIN_KOJI_DIR"/config <<- EOF
[koji]
server = $KOJI_URL/kojihub
weburl = $KOJI_URL/koji
topurl = $KOJI_URL/kojifiles
topdir = $KOJI_DIR
authtype = ssl
cert = ~/.koji/client.crt
serverca = ~/.koji/serverca.crt
anon_retry = true
EOF
chown kojiadmin:kojiadmin "$ADMIN_KOJI_DIR"/config

# ------------------------------------------------------------------------------------------------------
## KOJI APPLICATION HOSTING
# ------------------------------------------------------------------------------------------------------

# Koji Filesystem Skeleton
mkdir -p "$KOJI_DIR"/{packages,repos,work,scratch,repos-dist}
chown -R "$HTTPD_USER":"$HTTPD_USER" "$KOJI_DIR"

## Apache Configuration Files

cat > /etc/httpd/conf.d/ssl.conf <<- EOF
ServerName $KOJI_SERVER_FQDN

Listen 443 https

#SSLPassPhraseDialog exec:/usr/libexec/httpd-ssl-pass-dialog

#SSLSessionCache         shmcb:/run/httpd/sslcache(512000)

SSLRandomSeed startup file:/dev/urandom  256
SSLRandomSeed connect builtin

<VirtualHost _default_:443>
    ErrorLog /var/log/httpd/ssl_error_log
    TransferLog /var/log/httpd/ssl_access_log
    LogLevel warn

    SSLEngine on
    SSLProtocol -all +TLSv1.2
    SSLCipherSuite EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EECDH+aRSA+SHA256:EECDH:EDH+aRSA:HIGH:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!DH:!SHA1
    SSLHonorCipherOrder on

    SSLCertificateFile $KOJI_PKI_DIR/kojihub.pem
    SSLCertificateKeyFile $KOJI_PKI_DIR/private/kojihub.key
    SSLCertificateChainFile $KOJI_PKI_DIR/koji_ca_cert.crt
    SSLCACertificateFile $KOJI_PKI_DIR/koji_ca_cert.crt
    SSLVerifyClient optional
    SSLVerifyDepth 10

    <Files ~ "\.(cgi|shtml|phtml|php3?)$">
        SSLOptions +StdEnvVars
    </Files>
    <Directory "/var/www/cgi-bin">
        SSLOptions +StdEnvVars
    </Directory>

    CustomLog /var/log/httpd/ssl_request_log "%t %h %{SSL_PROTOCOL}x %{SSL_CIPHER}x \"%r\" %b"
</VirtualHost>
EOF


cat > /etc/httpd/conf.modules.d/wsgi.conf <<- EOF
WSGISocketPrefix /run/httpd/wsgi
EOF
cat > /etc/httpd/conf.modules.d/ssl.conf <<- EOF
LoadModule ssl_module lib/httpd/modules/mod_ssl.so
EOF


#Check SELinux status
SELINUX_STATUS=$(getenforce)

if [[ "$SELINUX_STATUS" != "Disabled" ]];then
    # Configure SELinux to allow Apache write access to /mnt/koji
    setsebool -P allow_httpd_anon_write=1
    setsebool -P httpd_can_network_connect=1
    semanage fcontext -a -t public_content_rw_t "${KOJI_DIR}(/.*)?" 
    restorecon -r -v /mnt/koji
fi

# Allow ports 80 and 443 through firewall

if command -v firewall-cmd &> /dev/null;then
    if ! firewall-cmd --zone=public --query-port=80/tcp; then
        firewall-cmd --zone=public --permanent --add-port=80/tcp
    fi

    if ! firewall-cmd --zone=public --query-port=443/tcp; then
        firewall-cmd --zone=public --permanent --add-port=443/tcp
    fi

    firewall-cmd --reload
fi


# Enable apache server
systemctl enable --now httpd

# ------------------------------------------------------------------------------------------------------
## TEST KOJI CONNECTIVITY
# ------------------------------------------------------------------------------------------------------

if ! timeout 10s sudo -u kojiadmin koji moshimoshi; then
    echo "${MAGENTA}Koji Hub took too long to respond! Aborting...${NORMAL}"
    exit
fi

# ------------------------------------------------------------------------------------------------------
## KOJI BUILDER (KOJID)
# ------------------------------------------------------------------------------------------------------

# Deploy Koji Builder for repo tasks
sudo -u kojiadmin koji add-host "$KOJI_BUILDER_FQDN" "$NATIVE_ARCH"

# Add the host to the createrepo channel
sudo -u kojiadmin koji add-host-to-channel "$KOJI_BUILDER_FQDN" createrepo

# A note on capacity
sudo -u kojiadmin koji edit-host --capacity="$KOJID_CAPACITY" "$KOJI_BUILDER_FQDN"

# Generate certificates
pushd "$KOJI_PKI_DIR"
./gen-certs.sh "$KOJI_BUILDER_FQDN" "$KOJI_BUILDER_FQDN"
popd

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
maxjobs=$KOJID_CAPACITY
topdir=$KOJI_MOUNT_DIR
workdir=/tmp/koji
mockdir=/var/lib/mock
mockuser=kojibuilder
mockhost=generic-linux-gnu
user=$KOJI_BUILDER_FQDN
server=$KOJI_URL/kojihub
topurl=$KOJI_URL/kojifiles
use_createrepo_c=True
cert = $KOJI_PKI_DIR/$KOJI_BUILDER_FQDN.pem
serverca = $KOJI_PKI_DIR/koji_ca_cert.crt
EOF

systemctl enable --now kojid

# ------------------------------------------------------------------------------------------------------
## KOJIRA - DNF|YUM REPOSITORY CREATION AND MAINTENANCE
# ------------------------------------------------------------------------------------------------------

# Add the user entry for the kojira user
sudo -u kojiadmin koji add-user kojira
sudo -u kojiadmin koji grant-permission repo kojira

# Kojira Configuration Files
mkdir -p /etc/kojira
cat > /etc/kojira/kojira.conf <<- EOF
[kojira]
server=$KOJI_URL/kojihub
topdir=$KOJI_DIR
logfile=/var/log/kojira.log
cert = $KOJI_PKI_DIR/kojira.pem
serverca = $KOJI_PKI_DIR/koji_ca_cert.crt
EOF

# Ensure postgresql is started prior to running kojira service
mkdir -p /etc/systemd/system/kojira.service.d
cat > /etc/systemd/system/kojira.service.d/after-postgresql.conf <<EOF
[Unit]
After=postgresql.service
EOF

systemctl enable --now kojira

# ------------------------------------------------------------------------------------------------------

printf "${GREEN}
----------------------------------
Successfully Deployed Koji Server!
----------------------------------
${NORMAL}"

# EOF
