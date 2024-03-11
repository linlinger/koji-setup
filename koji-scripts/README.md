# Koji Scripts

Based on [Clear Linux koji scripts](https://github.com/clearlinux/koji-setup-scripts)

Modified to deploy Koji infrastructure on Fedora and derivatives such as CentOS and other Enterprise Linux distributions.

---

## Setup
 Execute `deploy-koji.sh` as root

 ```sh
 sudo ./deploy-koji.sh
 ```

 The script will deploy everything on a single machine including the koji hub, builder, database and repository. The native builder can handle architecture agnostic tasks such repo creation.
 
 Deploy your own SCM server with Gitea or Gitlab or something similar if you need custom patched programs.

 After this, you may execute :
 ```sh
 sudo ./bootstrap-server.sh
 ```

This script bootstraps the server and database with tags, target and default koji build groups associated with tags.


