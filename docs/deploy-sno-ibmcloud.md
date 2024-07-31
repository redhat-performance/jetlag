# Deploy Single Node OpenShift clusters on IBMcloud via Jetlag quickstart

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](../docs/order-hardware-ibmcloud.md) in [docs](../docs) directory.

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure Ansible vars `ibmcloud.yml`](#configure-ansible-vars-ibmcloudyml)
- [Review SNO `ibmcloud.yml`](#review-sno-ibmcloudyml)
- [Run playbooks](#run-playbooks)
<!-- /TOC -->

<!-- Bastion setup is duplicated in multiple files and should be kept in sync!
     - deploy-bm-alias.md
     - deploy-bm-byol.md
     - deploy-bm-ibmcloud.md
     - deploy-bm-scale.md
     - deploy-sno-alias.md
     - deploy-sno-ibmcloud.md
     - deploy-sno-scale.md
 -->
## Bastion setup

1. Select the bastion machine from the allocation. You should run Jetlag on the
bastion machine, to ensure full connectivity and fastest access. By convention
this is usually the first node of your allocation: for example, the first machine
listed in your cloud platform's standard inventory display.

2. You can copy your ssh public key to the designated bastion machine to make it easier to
repeatedly log in from your laptop:

```console
[user@<local> ~]$ ssh-copy-id root@<bastion>
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 2 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Warning: Permanently added '<bastion>,x.x.x.x' (ECDSA) to the list of known hosts.
root@<bastion>'s password:

Number of key(s) added: 2

# Now try logging into the machine, and confirm that only the expected key(s)
# were added to ~/.ssh/known_hosts
[user@<local> ~]$ ssh root@<bastion>
[root@<bastion> ~]#
```

Now log in to the bastion (with `ssh root@<bastion>` if you copied your public key above,
or using the bastion root account password if not), because the remaining commands
should be executed from the bastion.

3. Install some additional tools to help after reboot

```console
[root@<bastion> ~]# dnf install tmux git python3-pip sshpass -y
Updating Subscription Management repositories.
...
Complete!
```

4. Setup ssh keys for the bastion root account and copy to itself to permit
local ansible interactions:

```console
[root@<bastion> ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:uA61+n0w3Dht4/oIy1IKXrSgt9tfC/8zjICd7LJ550s root@<bastion>
The key's randomart image is:
+---[RSA 3072]----+
...
+----[SHA256]-----+
[root@<bastion> ~]# ssh-copy-id root@localhost
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:fvvO3NLxT9FPcoOKQ9ldVdd4aQnwuGVPwa+V1+/c4T8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@localhost's password:

Number of key(s) added: 1
```

Now log in to the bastion (with `ssh root@<bastion>` if you copied your public key above,
or using the bastion root account password if not), because the remaining commands
should be executed from the bastion.

5. Clone the `jetlag` GitHub repo

```console
[root@<bastion> ~]# git clone https://github.com/redhat-performance/jetlag.git
Cloning into 'jetlag'...
remote: Enumerating objects: 4510, done.
remote: Counting objects: 100% (4510/4510), done.
remote: Compressing objects: 100% (1531/1531), done.
remote: Total 4510 (delta 2450), reused 4384 (delta 2380), pack-reused 0
Receiving objects: 100% (4510/4510), 831.98 KiB | 21.33 MiB/s, done.
Resolving deltas: 100% (2450/2450), done.
```

The `git clone` command will normally set the local head to the Jetlag repo's
`main` branch. To set your local head to a different branch or tag (for example,
a development branch), you can add `-b <name>` to the command.

Change your working directory to the repo's `jetlag` directory, which we'll assume
for subsequent steps:

```console
[root@<bastion> ~]# cd jetlag
[root@<bastion> jetlag]#
```

6. Download your `pull_secret.txt` from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads) into the root directory of your Jetlag repo on the bastion. You'll find the Pull Secret near the end of
the long downloads page, in the section labeled "Tokens". You can either click the "Download" button, and then copy the
downloaded file to `~/jetlag/pull_secret.txt` on the bastion (notice that Jetlag expects an underscore (`_`) while the
file will download with a hyphen (`-`)); *or* click on the "Copy" button, and then paste the clipboard into the terminal
after typing `cat >pull_secret.txt` on the bastion to create the expected filename:

```console
[root@<bastion> jetlag]# cat >pull_secret.txt
{
  "auths": {
    "quay.io": {
      "auth": "XXXXXXX",
      "email": "XXXXXXX"
    },
    "registry.connect.redhat.com": {
      "auth": "XXXXXXX",
      "email": "XXXXXXX"
    },
    "registry.redhat.io": {
      "auth": "XXXXXXX",
      "email": "XXXXXXX"
    }
  }
}
```

If you are deploying nightly builds then you will need to add a ci token and an entry for
`registry.ci.openshift.org`. If you plan on deploying an ACM downstream build be sure to
include an entry for `quay.io:443`.

7. Execute the bootstrap script in the current shell, with `source bootstrap.sh`.
This will activate a local virtual Python environment configured with the Jetlag and
Ansible dependencies.

```console
[root@<bastion> jetlag]# source bootstrap.sh
Collecting pip
...
(.ansible) [root@<bastion> jetlag]#
```

You can re-enter that virtual environment when you log in to the bastion again
with:

```console
[root@<bastion> ~]# cd jetlag
[root@<bastion> jetlag]# source .ansible/bin/activate
```

<!-- End of duplicated setup text -->

## Configure Ansible vars `ibmcloud.yml`

Next copy the vars file so we can edit it.

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/ibmcloud.sample.yml ansible/vars/ibmcloud.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/ibmcloud.yml
```

Change `cluster_type` to `cluster_type: sno`

Change `private_network_cidr` to the network cidr for the private network of your hardware. For Example `private_network_cidr: X.X.X.0/26`

Clear out settings for `controlplane_network_api` and `controlplane_network_ingress`

## Review SNO `ibmcloud.yml`

The `ansible/vars/ibmcloud.yml` now resembles ..

```yaml
---
# ibmcloud sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Lab is ibmcloud in this case
lab: ibmcloud

cluster_type: sno

# Applies to bm clusters
worker_node_count:

# Enter whether the build should use 'dev' (early candidate builds) or 'ga' for Generally Available versions of OpenShift
# Empty value results in playbook failing with error message. Example of dev builds would be 'candidate-4.17', 'candidate-4.16'
# or 'latest' (which would point to the early candidate build of the latest in development release) and examples of 'ga' builds would
# be explicit versions like '4.15.20' or '4.16.0' or you could also use things like latest-4.16 to point to the latest z-stream of 4.16.
# Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp for a list of available builds for 'ga' releases and
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview for a list of 'dev' releases.
ocp_build: "ga"

# The version of the openshift-installer binary, undefined or empty results in the playbook failing with error message.
# Values accepted depended on the build chosen ('ga' or 'dev').
# For 'ga' builds some examples of what you can use are 'latest-4.13', 'latest-4.14' or explicit versions like 4.15.2
# For 'dev' builds some examples of what you can use are 'candidate-4.16' or just 'latest'
ocp_version: "latest-4.16"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned Jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull_secret.txt
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

bastion_public_interface: bond1

bastion_private_interfaces:
- bond0
- int0
- int1

dns_servers:
- X.X.X.X
- Y.Y.Y.Y

base_dns_name: performance-scale.cloud

################################################################################
# OCP node vars
################################################################################
# Network configuration for cluster control-plane nodes

# Applies to sno only and serves as machine network
private_network_cidr: X.X.X.0/26

private_network_prefix: 26

cluster_name: jetlag-ibm

# Only applies for bm cluster types
controlplane_network_api:
controlplane_network_ingress:

################################################################################
# Extra vars
################################################################################
# Append override vars below
```

## Run playbooks

Run the ibmcloud create inventory playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/ibmcloud-create-inventory.yml
...
```

The `ibmcloud-create-inventory.yml` playbook will create an inventory file `ansible/inventory/ibmcloud.local` from the ibmcloud cli data and the vars file.

The inventory file should resemble the [sample one provided](../ansible/inventory/ibmcloud-inventory-sno.sample).

Next run the `ibmcloud-setup-bastion.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml
...
```

Finally run the `ibmcloud-sno-deploy.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-sno-deploy.yml
...
```

If everything goes well you should have SNO(s) in about 50-60 minutes. You can interact with the SNOs from the bastion.

```console
(.ansible) [root@<bastion> jetlag]# cd sno/
(.ansible) [root@<bastion> sno]# oc --kubeconfig=jetlag-bm5/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm5   Ready    master,worker   48m   v1.21.1+051ac4f
(.ansible) [root@<bastion> sno]# oc --kubeconfig=jetlag-bm4/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm4   Ready    master,worker   48m   v1.21.1+051ac4f

```

You can also copy the kubeconfig to your local machine and interact with it if you are on the ibmcloud vpn, and add the appropriate `/etc/hosts` entries to your local `/etc/hosts` file.
