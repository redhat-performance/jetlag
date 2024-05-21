# Deploy Single Node OpenShift clusters on IBMcloud via jetlag quickstart

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](../docs/order-hardware-ibmcloud.md) in [docs](../docs) directory.

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [SNO var changes](#sno-var-changes)
- [Review SNO ibmcloud.yml](#review-sno-ibmcloudyml)
- [Run playbooks](#run-playbooks)
<!-- /TOC -->

<!-- Bastion setup is duplicated in multiple files and should be kept in sync!
     - bastion-deploy-bm-byol.md
     - bastion-bm-ibmcloud.md
     - deploy-sno-ibmcloud.md
     - deploy-sno-quickstart.md
 -->
## Bastion setup

1. Select the bastion machine from the allocation. You should run Jetlag on the
bastion machine, to ensure full connectivity and fastest access. By convention
this is usually the first node of your allocation: for example, the first machine
listed in your cloud platform's standard inventory display.

2. You can copy your ssh public key to the designated bastion machine to make it easier to
repeatedly log in from your laptop:

```console
[user@fedora ~]$ ssh-copy-id root@xxx-h01-000-r650.example.redhat.com
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 2 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Warning: Permanently added 'xxx-h01-000-r650.example.redhat.com,x.x.x.x' (ECDSA) to the list of known hosts.
root@xxx-h01-000-r650.example.redhat.com's password:

Number of key(s) added: 2

# Now try logging into the machine, and confirm that only the expected key(s)
# were added to ~/.ssh/known_hosts
[user@fedora ~] ssh root@xxx-h01-000-r650.example.redhat.com
[user@fedora ~]
```

3. Install some additional tools to help after reboot

```console
[root@xxx-r660 ~]# dnf install tmux git python3-pip sshpass -y
Updating Subscription Management repositories.
...
Complete!
```

4. Setup ssh keys for the bastion root account and copy to itself to permit
local ansible interactions:

```console
[root@xxx-r660 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:uA61+n0w3Dht4/oIy1IKXrSgt9tfC/8zjICd7LJ550s root@xxx-r660.machine.com
The key's randomart image is:
+---[RSA 3072]----+
...
+----[SHA256]-----+
[root@xxx-r660 ~]# ssh-copy-id root@localhost
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:fvvO3NLxT9FPcoOKQ9ldVdd4aQnwuGVPwa+V1+/c4T8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@localhost's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@localhost'"
and check to make sure that only the key(s) you wanted were added.
[root@xxx-r660 ~]#
```

5. Clone `jetlag`

```console
[root@xxx-r660 ~]# git clone https://github.com/redhat-performance/jetlag.git
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

6. Download your pull_secret.txt from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads) and place it in the root directory of `jetlag`

```console
[root@xxx-r660 jetlag]# cat pull_secret.txt
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

7. Change to `jetlag` directory, and then run `source bootstrap.sh`. This will
activate a local virtual Python environment configured with the Jetlag and
Ansible dependencies.

```console
[root@xxx-r660 ~]# cd jetlag/
[root@xxx-r660 jetlag]# source bootstrap.sh
Collecting pip
...
(.ansible) [root@xxx-r660 jetlag]#
```

You can re-enter that virtual environment when you log in to the bastion again
with:

```console
[root@xxx-r660 ~]# cd jetlag
[root@xxx-r660 ~]# source .ansible/bin/activate
```

<!-- End of duplicated setup text -->

## SNO var changes

Change `cluster_type` to `cluster_type: sno`

Change `sno_node_count` to the number of SNOs that should be provisioned. For Example `sno_node_count: 2`

Change `private_network_cidr` to the network cidr for the private network of your hardware. For Example `private_network_cidr: X.X.X.0/26`

Clear out settings for `controlplane_network_api` and `controlplane_network_ingress`

## Review SNO ibmcloud.yml

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

# Applies to sno clusters
sno_node_count: 2

# Versions are controlled by this release image. If you want to change images
# you must stop and rm all assisted-installer containers on the bastion and rerun
# the setup-bastion step in order to setup your bastion's assisted-installer to
# the version you specified
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.15.2-x86_64

# This should just match the above release image version (Ex: 4.15)
openshift_version: "4.15"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned jetlag repo, Example:
# [user@fedora jetlag]$ ls pull_secret.txt
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
[user@fedora jetlag]$ ansible-playbook ansible/ibmcloud-create-inventory.yml
...
```

The `ibmcloud-create-inventory.yml` playbook will create an inventory file `ansible/inventory/ibmcloud.local` from the ibmcloud cli data and the vars file.

The inventory file should resemble the [sample one provided](../ansible/inventory/ibmcloud-inventory-sno.sample).

Next run the `ibmcloud-setup-bastion.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml
...
```

Finally run the `ibmcloud-sno-deploy.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-sno-deploy.yml
...
```

If everything goes well you should have SNO(s) in about 50-60 minutes. You can interact with the SNOs from the bastion.

```console
[root@jetlag-bm0 ~]# cd sno/
[root@jetlag-bm0 sno]# oc --kubeconfig=jetlag-bm5/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm5   Ready    master,worker   48m   v1.21.1+051ac4f
[root@jetlag-bm0 sno]# oc --kubeconfig=jetlag-bm4/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm4   Ready    master,worker   48m   v1.21.1+051ac4f

```

You can also copy the kubeconfig to your local machine and interact with it if you are on the ibmcloud vpn, and add the appropriate `/etc/hosts` entries to your local `/etc/hosts` file.
