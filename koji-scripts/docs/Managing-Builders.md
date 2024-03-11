# Adding Builders

Builders in Koji refers to machines that poll the hub and take up build jobs.

Koji's terminology for builders is **hosts**.

## At the server end

1. Generate certificate for the builder

```other
cd /etc/pki/koji

sudo ./gen-certs.sh <BUILDER_FQDN> <BUILDER_FQDN>
```

Copy the `.pem` certificate and `koji_ca_cert.crt` to the builder machine.

2. Add builder entry to koji database via kojiadmin acccount

```other
koji add-host <BUILDER_FQDN> <arch>
```

`<arch>` could be x86_64, riscv64 etc.

3. Add builder to the default channel and adjust the load capacity

```other
koji add-host-to-channel <BUILDER_FQDN> default
```

```other
koji edit-host --capacity=1.5 <BUILDER_FQDN>
```

---

## At the host end

1. Install koji-builder

```other
sudo dnf install koji-builder
```

2. Set file permissions and groups

```other
sudo mkdir -p /etc/mock/koji

sudo mkdir -p /var/lib/mock

sudo mkdir -p /etc/pki/koji

sudo chown -R root:mock /var/lib/mock

sudo usermod -G mock kojibuilder
```

3. Place the copied ssl certificates to a directory. This could be any directory, here we copy it to `/etc/pki/koji`

```other
sudo cp *.pem *.crt /etc/pki/koji
```

4. Configure kojid with `/etc/kojid/kojid.conf`

```other
[kojid]

sleeptime=5

maxjobs=16

topdir=/mnt/koji

workdir=/tmp/koji

mockdir=/var/lib/mock

mockuser=kojibuilder

mockhost=generic-linux-gnu

user=<BUILDER_FQDN>

server=<Koji_Server_FQDN>/kojihub

topurl=<Koji_Server_FQDN>/kojifiles

use_createrepo_c=True

cert = /etc/pki/koji/<BUILDER_PQDN>.pem

serverca = /etc/pki/koji/koji_ca_cert.crt
```

5. Start kojid on the builder

```other
sudo systemctl enable --now kojid
```

