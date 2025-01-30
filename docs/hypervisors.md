# Jetlag Hypervisors

_**Table of Contents**_

<!-- TOC -->
- [Overview](#overview)
- [Network](#network)
- [Setup Hypervisors](#setup-hypervisors)
- [Hypervisor Network-Impairments](#hypervisor-network-impairments)
- [Create/Delete/Replace VMs](#create-delete-replace-vms)
- [Manifests](#manifests)
<!-- /TOC -->

## Overview

MNO cluster type will allocate remaining hardware that was not put in the inventory for the cluster as Hypervisor machines if `hv_inventory: true` is set in the `all.yml` vars file while running the `create-inventory.yml` playbook. This is typically used for testing ACM/MCE installed on a hub cluster such that the VMs will serve as host machines for spoke clusters.

Make sure to set and append the following vars in the "extra vars" section of the `vars/all.yml`

| Variable | Meaning |
| - | - |
| `hv_inventory` | Enables placing remaining cloud hardware into hypervisor host group in inventory file
| `hv_ssh_pass` | The ssh password to the hypervisor machines
| `hv_ip_offset` | Offsets hypervisor ip addresses to allow for future expansion of the "hub" cluster. For example, a setting of `10` allows the hub cluster to grow 10 nodes before the ip addresses will conflict with the hypervisors.
| `hv_vm_prefix` | Set to a specific prefix. Defaults to `sno` which produces VMs with hostnames `sno00001`, `sno00002`, ... `snoXXXXX`
| `hypervisor_nic_interface_idx` | Defaults to `1` and corresponds to Network 1 in the scalelab. The index is used to lookup which nic name will be bridged for the VMs.

The default VM resource configuration is:

* 8 vCPUs
* 18Gi Memory
* 120G Disk

The number of vms per hypervisor type depends largely on if there are extra disks with the default resource configuration. The count of vms per machine type is hard-coded in the `vars/lab.yml` file. If you want to customize the count adjust the value per the machine type as desired in the `vars/lab.yml`.

## Prerequisites

Versions:
* RHEL >= 9 (Hypervisors)

## Network

The hypervisors bridge a network interface that was determined at the `create-inventory.yml` playbook timeframe. Review your inventory before running `hv-setup.yml` to ensure the interface you intended was selected.

## Setup Hypervisors

After generating an inventory with the `create-inventory.yml` playbook, the hypervisor can be setup. Start by editing the vars

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/hv.sample.yml ansible/vars/hv.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/hv.yml
```

Pay close attention to these vars:

| Variable | Comment |
| - | - |
| `lab` | Likely `scalelab` as that is the only lab where this has been tested.
| `setup_hv_vm_dhcp` | Set to true if `dnsmasq` should be configured on each hypervisor to hand out static addresses to each VM.
| `base_dns_name` | If you set this for your hub cluster, then set it identically here
| `controlplane_network` | If you adjusted this for the hub cluster, make sure it matches for the hypervisors

Run hv-setup playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud42.local ansible/hv-setup.yml
```

## Hypervisor Network-Impairments

For testing where network impairments are required, we can apply latency/packet-loss/bandwidth impairments on the hypervisor nodes. The `create-inventory.yml` playbook automatically selects scale lab "network 1" nic names for the host var `nic` in the hypervisor inventory. To change this, adjust `hypervisor_nic_interface_idx` as an extra var applied to the `all.yml` vars file.

To apply network impairments, first copy the network-impairments sample vars file

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/network-impairments.sample.yml ansible/vars/network-impairments.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/network-impairments.yml
```

Make sure to set/review the following vars:

| Variable | Description |
| - | - |
| `install_tc` | toggles installing traffic control
| `apply_egress_impairments` and `apply_ingress_impairments` | toggles out-going or incoming traffic impairments
| `egress_delay` and `ingress_delay` | latency for egress/ingress in milliseconds
| `egress_packet_loss` and `ingress_packet_loss` | packet loss in percent (Example `0.01` for 0.01%)
| `egress_bandwidth` and `ingress_bandwidth` | bandwidth in kilobits (Example `100000` which is 100000kbps or 100Mbps)

Apply impairments:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml
```

Remove impairments:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml -e 'apply_egress_impairments=false apply_ingress_impairments=false'
```

Note, egress impairments are applied directly to the impaired nic. Ingress impairments are applied to an ifb interface that handles ingress traffic for the impaired nic.

## Create/Delete/Replace VMs

Three playbooks are included to create, delete and replace the vms. All three playbooks depend on the same vars file and it should be copied in the same fashion as previous vars files:

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/hv.sample.yml ansible/vars/hv.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/hv.yml
```

The following vars apply to the manifests which are generated for deploying OCP clusters from ACM/MCE using the VMs as "emulated BareMetal Nodes":

| Variable name | Meaning |
| - | - |
| `ssh_public_key_file` | Sets the permitted ssh key to ssh into the node |
| `setup_hv_vm_dhcp` | Leaves the nmstateconfig portion out of the manifests |
| `hv_vm_manifest_type` | Determines which kind of manifest(s) the playbook will generate, choose from `sno`, `compact`, `standard`, and `jumbo` |
| `hv_vm_manifest_acm_cr` | Set to true if you want ACM CRs generated with the manifests |
| `compact_cluster_count` | If `hv_vm_manifest_type: compact`, then this determines the number of compact cluster siteconfigs to generate. Each compact cluster consists of 3 vms, be careful not to exceed the entire count of vms. |
| `standard_cluster_count` | If `hv_vm_manifest_type: standard`, then this determines the number of standard cluster siteconfigs to generate. It will include `standard_cluster_node_count` count of vms in each standard cluster siteconfig. Be careful not to exceed the entire count of vms. |

Run create vms:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud42.local ansible/hv-vm-create.yml
```

Run replace vms (Deletes then creates vms):

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud42.local ansible/hv-vm-replace.yml
```

Run delete vms:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud42.local ansible/hv-vm-delete.yml
```

## Manifests and Siteconfigs

When you create vms, depending upon what `hv_vm_manifest_type`, you will find pre-generated manifests to either deploy SNOs or traditional OCP clusters using ACM/MCE. Those manifests and siteconfigs are located in:

```console
# ls -lh /root/hv-vm/
total 0
drwxr-xr-x. 3 root root 23 Jul 22 18:34 jumbo
(.ansible) [root@<bastion> jetlag]# ls -lh /root/hv-vm/jumbo/manifests/
total 456K
-rw-r--r--. 1 root root 453K Jul 22 18:51 manifest.yml
```

As expected, cluster type of `jumbo` includes just one yaml file with all the manifests to create the jumbo cluster.

```console
(.ansible) [root@<bastion>jetlag]# ls -lh /root/hv-vm/compact/siteconfigs/
total 400K
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00001-resources.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00001-siteconfig.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00002-resources.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00002-siteconfig.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00003-resources.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00003-siteconfig.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00004-resources.yml
-rw-r--r--. 1 root root 97K Jul 22 19:30 compact-00004-siteconfig.yml
```

Compact type generates a siteconfig per cluster consisting of exactly `3` nodes. Standard type generates siteconfigs consisting of `standard_cluster_node_count` number of nodes.

SNO manifests are a directory per manifest since each SNO is a single node with several CRs.
