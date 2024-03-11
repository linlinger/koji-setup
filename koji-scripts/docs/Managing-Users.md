# Adding Users

Users in Koji refers to people/computers that can issue commands to the koji hub to build and tag packages.

*NOTE* : Koji can only add new users, it currently, cannot remove them.

## On the server

#### 1. Add new user to koji database

Switch to kojiadmin user execute :

```other
koji add-user <username>
```

Koji uses this `username` to authorise, so it is assumed you are using this username to issue commands.

#### 2. Generate certificates for the new user

```other
cd /etc/pki/koji/

sudo ./gen-certs.sh <username> <username>
```

Copy the generated certificates in `.pem` , `.crt` ,`.pkcs12` and the `koji_ca_cert.crt` file the user's account and machine.

---

## On the user account/machine

#### 1. Install koji

```other
sudo dnf install koji
```

#### 1. Copy the certificates to appropriate directories

```other
mkdir -p ~/.koji

cp *.pem ~/.koji/client.crt
cp koji_ca_cert.crt ~/.koji/clientca.crt
cp koji_ca_cert.crt ~/.koji/serverca.crt
```

#### 3. Create the koji config file for user

```other
cat > ~/.koji/config <<-EOF
[koji]

server = http://KojiFQDN/kojihub

weburl = http://KojiFQDN/koji

topurl = http://KojiFQDN/kojifiles

topdir = /mnt/koji

authtype = ssl

cert = ~/.koji/client.crt

serverca = ~/.koji/serverca.crt

anon_retry = true

EOF
```

#### 4. Ping the kojihub

```other
koji hello
```

---

## Post setup

### Permission Management

```other
koji grant-permission [--new] <permission> <user>

koji revoke-permission <permission> <user>

koji list-permissions --user <user>
```

#### Administration

The following permissions govern access to key administrative actions.

`admin`

This is a superuser access without any limitations, so grant with caution. Users with admin effectively have every other permission. We recommend granting the smallest effective permission.

`host`

Restricted admin permission for handling host-related management tasks.

`tag`

Permission for adding/deleting/editing tags. Allows use of the`tagBuildBypass` and `untagBuildBypass` API calls also. Note, that this name could be confusing as it is not related to tagging builds but to editing tags themselves. Tagging builds (and adding/removing packages from package lists for given tags) is handled by `tag` and `package_list` policies respectively.

`target`


