# Deploy Single Node OpenShift Clusters on IBMcloud via Jetlag

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](../docs/order-hardware-ibmcloud.md) in [docs](../docs) directory.

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure Ansible vars `ibmcloud.yml`](#configure-ansible-vars-ibmcloudyml)
- [Review SNO `ibmcloud.yml`](#review-sno-ibmcloudyml)
- [Run playbooks](#run-playbooks)
<!-- /TOC -->

## Bastion setup

Follow the [Bastion Setup](bastion-setup.md) guide to prepare your bastion machine before proceeding.

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

# Applies to mno clusters
worker_node_count:

# Set ocp_build to "ga", `dev`, or `ci` to pick a specific nightly build
ocp_build: "ga"

# ocp_version is used in conjunction with ocp_build
# For "ga" builds, examples are "latest-4.22", "latest-4.21", "4.22.1" or "4.21.7"
# For "dev" builds, examples are "candidate-4.22", "candidate-4.21" or "latest"
# For "ci" builds, an example is "4.19.0-0.nightly-2025-02-25-035256"
ocp_version: "latest-4.21"

# Enables Operators CNV and LSO install at deployment timeframe (GA releases only)
enable_cnv_install: false

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
# Place your pull-secret.txt in the base directory of the cloned Jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull-secret.txt
pull_secret: "{{ lookup('file', '../pull-secret.txt') }}"

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

# Only applies for mno cluster types
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
