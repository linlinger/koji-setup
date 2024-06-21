# Koji Scripts

Shell scripts to deploy and manage Koji server for custom RPM based Linux distribution.

Based on [Clear Linux koji scripts](https://github.com/clearlinux/koji-setup-scripts) and modified to deploy Koji infrastructure for Fedora and derivatives such as CentOS and Enterprise Linux distributions.

---

## Setup

1. Edit [configuration parameters](./parameters.sh) as required.

2. Execute `deploy-koji.sh` as root

 ```sh
 sudo ./deploy-koji.sh
 ```

The script will deploy everything on a single machine including the koji hub, builder, database and repository. The native builder can handle architecture agnostic tasks such repo creation.

For custom or downstream packages, deploy your own SCM server using a Forgejo or the likes and add the URL to `allowed_scms` list in builder.

---

To get started with tags, run :
 ```sh
 sudo ./bootstrap-server.sh <tag_name> [arches]
 ```




