# Deploy Single Node OpenShift clusters on IBMcloud via jetlag quickstart

To deploy Single Node OpenShift (SNO) clusters on IBMcloud hardware you can simply follow the bare metal cluster guide with a few differences. The changes in this guide will apply after [Review ibmcloud.yml](deploy-bm-ibmcloud.md#review-ibmcloudyml) section.

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](../docs/order-hardware-ibmcloud.md) in [docs](../docs) directory.

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
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.9.10-x86_64

# This should just match the above release image version (Ex: 4.9)
openshift_version: "4.9"

# List type: Use only one of OpenShiftSDN or OVNKubernetes for BM/RWN, but could be both for SNO mix and match
networktype:
  - OVNKubernetes

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
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
private_bond_interfaces:
- enp1s0f0
- enp2s0f0

# Applies to sno only and serves as machine network
private_network_cidr: X.X.X.0/26

private_network_prefix: 26

cluster_name: jetlag-ibm

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
