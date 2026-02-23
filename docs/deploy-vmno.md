# Virtual MultiNode OpenShift

A VMNO cluster is a MNO cluster that uses virtual machines instead of bare metal machines in jetlag.

> [!NOTE]
> VMNO is a made up term solely for Jetlag.

VMNO allows jetlag to deploy multi-node clusters with a smaller machine count than required for a typical MNO bare metal cluster. For example with a 3 node allocation, you can create a MNO cluster using VMNO. The first machine will be the bastion machine and the two additional machines will be the hypervisors. You could even do this with just two machines (1 Bastion, 1 Hypervisor) however you will likely require some specific tuning of VMs and or capacity planning of your hardware to ensure you properly resource your cluster's VMs.

_**Table of Contents**_

<!-- TOC -->
- [Virtual MultiNode OpenShift](#virtual-multinode-openShift)
- [Deploy a VMNO](#deploy-a-vmno)
  - [Configure Ansible vars in `all.yml`](#configure-ansible-vars-in-allyml)
	- [Lab \& cluster infrastructure vars](#lab--cluster-infrastructure-vars)
	- [Bastion node vars](#bastion-node-vars)
	- [OCP node vars](#ocp-node-vars)
	- [Extra vars](#extra-vars)
  - [Configure Ansible vars in `hv.yml`](#configure-ansible-vars-in-hvyml)
  - [Review vars `all.yml` and `hv.yml`](#review-vars-allyml-and-hvyml)
  - [Run playbooks](#run-playbooks)
    - [Run `create-inventory.yml` playbook](#run-create-inventoryyml-playbook)
    - [Run `setup-bastion.yml` playbook](#run-setup-bastionyml-playbook)
    - [Run `hv-setup.yml` playbook](#run-hv-setupyml-playbook)
    - [Run `hv-vm-create.yml` playbook](#run-hv-vm-createyml-playbook)
    - [Run `mno-deploy.yml` playbook](#run-mno-deployyml-playbook)
  - [Monitor install and interact with cluster](#monitor-install-and-interact-with-cluster)
<!-- /TOC -->

# Deploy a VMNO

This quickstart assumes you already have selected a bastion, setup ssh, downloaded your pull-secret.txt and cloned the jetlag repo. An example cloud consisting of Dell r740xds called `cloud99` in the performancelab is used for the example.

The main steps to deploy a VMNO are as follows

1. Configure vars in `ansible/vars/all.yml` and in `ansible/vars/hv.yml`
2. Run `create-inventory.yml` playbook and review inventory file
3. Run `setup-bastion.yml` playbook
4. Run `hv-setup.yml` playbook
5. Run `hv-vm-create.yml` playbook
6. Run `mno-deploy.yml` playbook

Repeated runs require deleting VMs (`hv-vm-delete.yml` or `hv-vm-replace.yml` playbooks) prior to rerunning `mno-deploy.yml` after the initial deployment.

> [!WARNING]
> Adjusting variables that cause the count of VMs to differ in the inventory file without deleting the VMs beforehand can result in leftover VMs that can cause issues during deployment. Ensuring all VMs are deleted before adjusting inventory size or VM counts per hardware will prevent any mismatches or VM conflicts.

## Configure Ansible vars in `all.yml`

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: performancelab`

Change `lab_cloud` to `lab_cloud: cloud99`

Change `cluster_type` to `cluster_type: vmno`

Set `worker_node_count` to limit the number of worker nodes. Set it to `0` if you want a 3 node compact cluster. For this example `worker_node_count` is set to `5` such that the entire cluster will be 8 nodes (3 controlplane + 5 workers).

Set `ocp_build` to `ga` for Generally Available versions, `dev` (early candidate builds)
of OpenShift, or `ci` to pick a specific nightly build.

`ocp_version` is used in conjunction with `ocp_build`. Examples of `ocp_version` with
`ocp_build: ga` include explicit versions such as `4.17.17` or `4.16.35`, additionally
`latest-4.17` or `latest-4.16` point to the latest z-stream of 4.17 and 4.16 ga builds.
Examples of `ocp_version` with `ocp_build: dev` are `candidate-4.17`, `candidate-4.16`
or `latest` which points to the early candidate build of the latest in development
release. Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp/ for a list
of available builds for `ga` releases and https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/
for a list of `dev` releases. Nightly `ci` builds are tricky and require determining
exact builds you can use, an example of `ocp_version` with `ocp_build: ci` is
`4.19.0-0.nightly-2025-02-25-035256`, For 'ci' builds check latest nightly from  https://amd64.ocp.releases.ci.openshift.org/.


Note: user has to add registry.ci.openshift.org token in pull-secret.txt for `ci` builds.

### Bastion node vars

The bastion system type determines the values of `bastion_lab_interface` and `bastion_controlplane_interface`.

Using the performance lab networking table, determine the names of the nic per network.

* `bastion_lab_interface` will always be set to the nic name under "Public"
* `bastion_controlplane_interface` should be set to the nic name under "EM1" for this guide

For Dell r740xd set those vars to the following

```yaml
bastion_lab_interface: eno3
bastion_controlplane_interface: eno1
```

Double check your nic names with your bastion machine.

### OCP node vars

No vars need to be adjusted in this section.

### Extra vars

Append several hypervisor overrides here:

```yaml
hv_ssh_pass: xxxxx
hv_ip_offset: 0
hv_vm_ip_offset: 20
```

Replace `xxxxx` with the password for sshing to the bare metal machines in the allocation.

For hardware in the performancelab, there are no default VM count per disks set. For the example Dell r740xd, the following counts were used:

```yaml
hw_vm_counts:
  performancelab:
    r740xd:
      default: 3
      nvme0n1: 7
```

> [!NOTE]
> Depending upon your hardware, you may have to parition and format a 2nd disk to help store VM disk files.

## Configure Ansible vars in `hv.yml`

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/hv.sample.yml ansible/vars/hv.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/hv.yml
```

Change `lab` to `lab: performancelab`

Change `hv_vm_generate_manifests` to `hv_vm_generate_manifests: false`

VM manifests are only used in conjunction with ACM/MCE testing.

## Review vars `all.yml` and `hv.yml`

The `ansible/vars/all.yml` now resembles ...

```yaml
---
# Sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Which lab to be deployed into (Ex scalelab)
lab: performancelab
# Which cloud in the lab environment (Ex cloud42)
lab_cloud: cloud99

# Either mno or sno
cluster_type: vmno

# Applies to mno clusters
worker_node_count: 5

# Set ocp_build to "ga", `dev`, or `ci` to pick a specific nightly build
ocp_build: ga

# ocp_version is used in conjunction with ocp_build
# For "ga" builds, examples are "latest-4.17", "latest-4.16", "4.17.17" or "4.16.35"
# For "dev" builds, examples are "candidate-4.17", "candidate-4.16" or "latest"
# For "ci" builds, an example is "4.19.0-0.nightly-2025-02-25-035256"
ocp_version: "latest-4.20"

# Set to true ONLY if you have a public routable vlan in your scalelab or performancelab cloud.
# Autoconfigures cluster_name, base_dns_name, controlplane_network_interface_idx, controlplane_network,
# controlplane_network_prefix, and controlplane_network_gateway to the values required for your cloud's public VLAN.
# SNO configures only the first cluster on the api dns resolvable address
# MNO/SNO still requires the correct value for bastion_controlplane_interface
public_vlan: false

# SNOs only require a single IP address and can be deployed using the lab DHCP interface instead of a private or
# public vlan network. Set to true to have your SNO deployed on the public lab DHCP network.
# Cannot combine public_vlan and sno_use_lab_dhcp
sno_use_lab_dhcp: false

# Enables FIPs security standard
enable_fips: false

# Enables Operators CNV and LSO install at deployment timeframe (GA releases only)
enable_cnv_install: false

ssh_private_key_file: ~/.ssh/id_rsa
ssh_public_key_file: ~/.ssh/id_rsa.pub
# Place your pull-secret.txt in the base directory of the cloned jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull-secret.txt
pull_secret: "{{ lookup('file', '../pull-secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

smcipmitool_url:

bastion_lab_interface: eno3
bastion_controlplane_interface: eno1

# Sets up Gogs a self-hosted git service on the bastion
setup_bastion_gogs: false

# Set to enable and sync container images into a container image registry on the bastion
setup_bastion_registry: false

# Use in conjunction with ipv6 based clusters
use_bastion_registry: false

################################################################################
# OCP node vars
################################################################################
# Network configuration for all mno/sno cluster nodes
controlplane_lab_interface: eno1np0

################################################################################
# Extra vars
################################################################################
# Append override vars below
hv_ssh_pass: xxxxx
hv_ip_offset: 0
hv_vm_ip_offset: 20
hw_vm_counts:
  performancelab:
    r740xd:
      default: 3
      nvme0n1: 7
```

The `ansible/vars/hv.yml` now resembles ...

```yaml
---
# Hypervisor sample vars file

# Which lab to be deployed into (Ex scalelab)
lab: performancelab

ssh_public_key_file: ~/.ssh/id_rsa.pub

install_tc: true

# Setup and use coredns instead of dnsmasq
setup_coredns: false

# Enables using DHCP instead of relying on static network configuration for VMs
setup_hv_vm_dhcp: false

hv_vm_generate_manifests: false

# Types: sno, compact, standard, mixed, jumbo
# sno = 1 node per cluster
# compact = 3 nodes per cluster
# standard = 5 nodes or more per cluster (3 control-plane, 2 or more workers)
# mixed = provisions sno, compact, and standard as determined by below counts
# jumbo = all vms for the one cluster (Can not be combined because consumes all available vms)
hv_vm_manifest_type: sno

# If hv_vm_manifest_type is set to mixed, compact or standard, use these vars to adjust the count of clusters and size of standard clusters
# sno_cluster_count does not apply when hv_vm_manifest_type is set to sno
# Careful not to exceed the count of your VMs
# Example:
# sno_cluster_count: 442
# compact_cluster_count: 100
# standard_cluster_count: 100
# standard_cluster_node_count: 5
# Requires 1242 VMS (442 * 1) + (100 * 3) + (100 * 5) when set to mixed
sno_cluster_count: 0
compact_cluster_count: 0
standard_cluster_count: 0
standard_cluster_node_count: 5

# The cluster imageset used in the manifests
cluster_image_set: openshift-4.16.3

# Include ACM CRs in the manifests
hv_vm_manifest_acm_cr: true

# Retrieves the bastion pull-secret instead of below pull-secret
use_bastion_registry: false
# Provide pull-secret for connected manifests
pull_secret: "{{ lookup('file', '../pull-secret.txt') | b64encode }}"
```

## Run playbooks

### Run `create-inventory.yml` playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
...
```

The `create-inventory.yml` playbook will create an inventory file `ansible/inventory/cloud99.local` from the lab allocation data and the vars file.

The inventory file resembles ...

```
[all:vars]
allocation_node_count=3
supermicro_nodes=False
cluster_name=mno
controlplane_network=198.18.0.0/16
controlplane_network_prefix=16
base_dns_name=example.com

[bastion]
xxx-h31-000-r740xd.example.com ansible_ssh_user=root bmc_address=mgmt-xxx-h31-000-r740xd.example.com lab_ip=10.1.x.x

[bastion:vars]
bmc_user=quads
bmc_password=XXXXXXX

[controlplane]
vm00001 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.20 mac_address=52:54:00:00:00:01 domain_uuid=4e353905-a9fa-5aaa-974a-01d8f03aebf2 vendor=Libvirt install_disk=/dev/sda
vm00002 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.21 mac_address=52:54:00:00:00:02 domain_uuid=73ff0a68-faa5-58fe-90df-112dbe66163e vendor=Libvirt install_disk=/dev/sda
vm00003 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.22 mac_address=52:54:00:00:00:03 domain_uuid=18b97bda-fcec-5328-a2c1-acfdc3a9a92e vendor=Libvirt install_disk=/dev/sda


[controlplane:vars]
role=master
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
network_interface=eth0
network_prefix=16
gateway=198.18.0.1
dns1=198.18.0.1

[worker]
vm00004 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.23 mac_address=52:54:00:00:00:04 domain_uuid=1c407140-933b-56e2-a61e-890f0687cb02 vendor=Libvirt install_disk=/dev/sda
vm00005 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.24 mac_address=52:54:00:00:00:05 domain_uuid=1912f288-223d-54fb-b725-190e32747866 vendor=Libvirt install_disk=/dev/sda
vm00006 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.25 mac_address=52:54:00:00:00:06 domain_uuid=dae097b5-4296-5d3f-8cc4-4acee86b3676 vendor=Libvirt install_disk=/dev/sda
vm00007 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.26 mac_address=52:54:00:00:00:07 domain_uuid=54690a27-5069-5f72-9bad-ca66e6097ee0 vendor=Libvirt install_disk=/dev/sda
vm00008 bmc_address=xxx-h35-000-r740xd.example.com ip=198.18.0.27 mac_address=52:54:00:00:00:08 domain_uuid=0a07362c-964a-5674-85be-344d9ab8153a vendor=Libvirt install_disk=/dev/sda


[worker:vars]
role=worker
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
network_interface=eth0
network_prefix=16
gateway=198.18.0.1
dns1=198.18.0.1

[sno]
# Unused

[sno:vars]
# Unused

[hv]
xxx-h35-000-r740xd.example.com bmc_address=mgmt-xxx-h35-000-r740xd.example.com vendor=Dell ip=198.18.0.8 nic=eno1 disk2_enable=True disk2_device=nvme0n1
xxx-h37-000-r740xd.example.com bmc_address=mgmt-xxx-h37-000-r740xd.example.com vendor=Dell ip=198.18.0.9 nic=eno1 disk2_enable=True disk2_device=nvme0n1

[hv:vars]
ansible_user=root
ansible_ssh_pass=xxxxx
bmc_user=quads
bmc_password=XXXXXXX
network_prefix=16

[hv_vm]
vm00001 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.20 cpus=8 memory=18 disk_size=120 vnc_port=5901 mac_address=52:54:00:00:00:01 domain_uuid=4e353905-a9fa-5aaa-974a-01d8f03aebf2 disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00002 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.21 cpus=8 memory=18 disk_size=120 vnc_port=5902 mac_address=52:54:00:00:00:02 domain_uuid=73ff0a68-faa5-58fe-90df-112dbe66163e disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00003 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.22 cpus=8 memory=18 disk_size=120 vnc_port=5903 mac_address=52:54:00:00:00:03 domain_uuid=18b97bda-fcec-5328-a2c1-acfdc3a9a92e disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00004 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.23 cpus=8 memory=18 disk_size=120 vnc_port=5904 mac_address=52:54:00:00:00:04 domain_uuid=1c407140-933b-56e2-a61e-890f0687cb02 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00005 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.24 cpus=8 memory=18 disk_size=120 vnc_port=5905 mac_address=52:54:00:00:00:05 domain_uuid=1912f288-223d-54fb-b725-190e32747866 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00006 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.25 cpus=8 memory=18 disk_size=120 vnc_port=5906 mac_address=52:54:00:00:00:06 domain_uuid=dae097b5-4296-5d3f-8cc4-4acee86b3676 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00007 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.26 cpus=8 memory=18 disk_size=120 vnc_port=5907 mac_address=52:54:00:00:00:07 domain_uuid=54690a27-5069-5f72-9bad-ca66e6097ee0 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00008 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.27 cpus=8 memory=18 disk_size=120 vnc_port=5908 mac_address=52:54:00:00:00:08 domain_uuid=0a07362c-964a-5674-85be-344d9ab8153a disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00009 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.28 cpus=8 memory=18 disk_size=120 vnc_port=5909 mac_address=52:54:00:00:00:09 domain_uuid=85c01540-e030-568a-b70a-1952f13f4e44 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00010 ansible_host=xxx-h35-000-r740xd.example.com hv_ip=198.18.0.8 ip=198.18.0.29 cpus=8 memory=18 disk_size=120 vnc_port=5910 mac_address=52:54:00:00:00:0a domain_uuid=c0dbc3ca-da8f-5dec-bd5d-d751d8b5efb8 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750

vm00011 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.30 cpus=8 memory=18 disk_size=120 vnc_port=5901 mac_address=52:54:00:00:00:0b domain_uuid=412a3810-f3d7-5078-abbe-111a20d6bbf3 disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00012 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.31 cpus=8 memory=18 disk_size=120 vnc_port=5902 mac_address=52:54:00:00:00:0c domain_uuid=41c8891d-b370-568a-9e37-9c075fa71707 disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00013 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.32 cpus=8 memory=18 disk_size=120 vnc_port=5903 mac_address=52:54:00:00:00:0d domain_uuid=d66594e6-113b-5c2c-b8c7-9d5683d7ee03 disk_location=/var/lib/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00014 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.33 cpus=8 memory=18 disk_size=120 vnc_port=5904 mac_address=52:54:00:00:00:0e domain_uuid=adc9f551-60d9-54fa-ade5-12c39a17eb74 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00015 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.34 cpus=8 memory=18 disk_size=120 vnc_port=5905 mac_address=52:54:00:00:00:0f domain_uuid=8242d36d-daf0-556a-8bbd-29447f9ad262 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00016 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.35 cpus=8 memory=18 disk_size=120 vnc_port=5906 mac_address=52:54:00:00:00:10 domain_uuid=48ffcf06-1cb9-5d4a-9fec-bb20e64eda02 disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00017 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.36 cpus=8 memory=18 disk_size=120 vnc_port=5907 mac_address=52:54:00:00:00:11 domain_uuid=e54ebdd7-c872-5c48-8fc9-af9a80f2445a disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00018 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.37 cpus=8 memory=18 disk_size=120 vnc_port=5908 mac_address=52:54:00:00:00:12 domain_uuid=e7a17c6c-2bf3-5f08-8401-f11dbbceacfb disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00019 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.38 cpus=8 memory=18 disk_size=120 vnc_port=5909 mac_address=52:54:00:00:00:13 domain_uuid=a6f9ca66-e6be-56c5-b95a-0563f29f549d disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750
vm00020 ansible_host=xxx-h37-000-r740xd.example.com hv_ip=198.18.0.9 ip=198.18.0.39 cpus=8 memory=18 disk_size=120 vnc_port=5910 mac_address=52:54:00:00:00:14 domain_uuid=d32b38ef-1b35-5f6a-8dae-d13a3f70111a disk_location=/mnt/disk2/libvirt/images bw_avg=11500 bw_peak=12500 bw_burst=11750

[hv_vm:vars]
ansible_user=root
ansible_ssh_pass=xxxxx
base_domain=example.com
machine_network=198.18.0.0/16
network_prefix=16
gateway=198.18.0.1
bw_limit=False
```

We can see jetlag has generated an inventory to create 10 VMs per hypervisor. This was due to the override for how many VMs we place on an r740xd. The first 3 VMs disk files are placed on the default disk which is the same disk as the RHEL OS is installed on:

Example:

```console
[root@xxx-h35-000-r740xd ~]# df -h /var/lib/libvirt/images/vm00001.qcow2
Filesystem                                   Size  Used Avail Use% Mounted on
/dev/mapper/rhel_xxx--h35--000--r740xd-root  1.7T  638G  1.1T  39% /
```

Where as the remaining 7 VMs are placed on a separate mount point using the 2nd disk

```console
[root@xxx-h35-000-r740xd ~]# df -h /mnt/disk2/libvirt/images/vm00004.qcow2
Filesystem      Size  Used Avail Use% Mounted on
/dev/nvme0n1p1  3.0T  974G  2.0T  33% /mnt/disk2
```

Now is a good time to customize your inventory to match the needs and capacity of your environment. By default jetlag assigns every VM with the same count of CPUs, Memory and Disk. This is overridable by appending

```yaml
hv_vm_cpu_count: 8
hv_vm_memory_size: 18
hv_vm_disk_size: 120
```

into the Extra vars section of the `all.yml` vars file. You can also edit the generated inventory file since the VMs will not be created until you run the `hv-vm-create.yml` playbook.

> [!WARNING]
> Not properly sizing your VMs for your allocation's hardware resources can result in overcommitment of resources, poor performance, or failure to deploy a cluster.


### Run `setup-bastion.yml` playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
...
```

### Run `hv-setup.yml` playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml
...
```

### Run `hv-vm-create.yml` playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml
...
```

### Run `mno-deploy.yml` playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
...
```


In case of a failure and the need to rerun the deploy playbook, you will need to delete and recreate your VMs. Two additional playbooks help manage the VMs between deployments - `hv-vm-delete.yml` and `hv-vm-replace.yml`

## Monitor install and interact with cluster

It is suggested to monitor your deployment to see if anything hangs on boot. You can monitor your deployment by opening the bastion's GUI to assisted-installer (port 8080, ex `xxx-h31-000-r740xd.example.com:8080`), sshing to your hypervisors and using `virsh` commands to observe VMs booting. You can also VNC into each VM to view the console while it boots and installs.

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion via the kubeconfig or kubeadmin password.

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/vmno/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
NAME      STATUS   ROLES                  AGE   VERSION
vm00001   Ready    control-plane,master   1d    v1.31.7
vm00002   Ready    control-plane,master   1d    v1.31.7
vm00003   Ready    control-plane,master   1d    v1.31.7
vm00004   Ready    worker                 1d    v1.31.7
vm00005   Ready    worker                 1d    v1.31.7
vm00006   Ready    worker                 1d    v1.31.7
vm00007   Ready    worker                 1d    v1.31.7
vm00008   Ready    worker                 1d    v1.31.7
(.ansible) [root@<bastion> jetlag]# cat /root/vmno/kubeadmin-password
xxxxx-xxxxx-xxxxx-xxxxx
```
