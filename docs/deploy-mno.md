# Deploy a Multi Node OpenShift Cluster via Jetlag

Assuming you received a Scale Lab or Performance Lab allocation named `cloud99`, this guide will walk you through getting a multi node cluster up in your allocation. You should run Jetlag directly on the bastion machine. Jetlag picks the first machine in an allocation as the bastion. See [Choosing a different bastion machine](bastion-setup.md#choosing-a-different-bastion-machine) if you need to change this.

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure Ansible vars in `all.yml`](#configure-ansible-vars-in-allyml)
  - [Lab \& cluster infrastructure vars](#lab--cluster-infrastructure-vars)
  - [Bastion node vars](#bastion-node-vars)
  - [Network configuration (IPv6 / dual-stack)](#network-configuration-ipv6--dual-stack)
  - [Extra vars](#extra-vars)
- [Review vars `all.yml`](#review-vars-allyml)
- [Run playbooks](#run-playbooks)
- [Monitor install and interact with cluster](#monitor-install-and-interact-with-cluster)
<!-- /TOC -->

## Bastion setup

Follow the [Bastion Setup](bastion-setup.md) guide to prepare your bastion machine before proceeding.

## Configure Ansible vars in `all.yml`

Copy the sample vars file and edit it:

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to match your environment:
- Scale Lab: `lab: scalelab`
- Performance Lab: `lab: performancelab`

Change `lab_cloud` to `lab_cloud: cloud99`

Change `cluster_type` to `cluster_type: mno`

Set `worker_node_count` to limit the number of worker nodes from your lab allocation. Set it to `0` if you want a 3 node compact cluster.

Set `ocp_build` and `ocp_version` to select your OpenShift version. For example, to deploy the latest GA 4.22 release:

```yaml
ocp_build: "ga"
ocp_version: "latest-4.22"
```

See [Updating OCP version](tips-and-vars.md#updating-ocp-version) for details on available builds and version formats.

**Deploy in the public VLAN:**

To deploy a cluster using the public VLAN, set `public_vlan: true`. Once enabled the following variables are automatically configured:

- `cluster_name`: cluster name according to the pre-existing DNS records in the public VLAN, i.e: `vlan604`
- `base_dns_name` is set to the proper base dns name in the inventory
- `controlplane_network_interface_idx`: Is set to the corresponding interface number
- `controlplane_network`: public VLAN subnet
- `controlplane_network_prefix`: public VLAN network mask
- `controlplane_network_gateway`: public VLAN default gateway

When the deployment is completed, the cluster API and routes should be reachable directly from the VPN.

### Bastion node vars

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your Jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/en/support/resources/downloadcenter/smsdownload).

**Network Interface Configuration:**

Jetlag automatically detects and configures network interfaces for common hardware in Scale Lab and Performance Lab using the `hw_nic_name` [mapping](../ansible/vars/lab.yml). You only need to manually set these if you want to override the defaults. For more details see [tips-and-vars.md](tips-and-vars.md).

Here you can see a network diagram for the multi node cluster with 3 workers and 3 master nodes:

![MNO Cluster](img/mno_cluster.png)

> [!NOTE]
> To use a different network than "Network 1" for your controlplane network, add the
> appropriate overrides to the Extra vars section of `all.yml`.
> See [tips and vars](tips-and-vars.md#using-other-network-interfaces) for more information.

> [!NOTE]
> If your machine types are not homogeneous, you may need to manually edit the generated
> inventory file to correct NIC names until this is reasonably automated.

### Network configuration (IPv6 / dual-stack)

The "Network Configuration" section of `all.yml` contains commented-out blocks for single-stack IPv4 (the default), single-stack IPv6, and dual-stack (IPv4 + IPv6). For a standard IPv4 deployment no changes are needed. For IPv6 or dual-stack, uncomment the appropriate block and adjust the values to match your environment.

For disconnected deployments, also set the following under "Bastion node vars":

```yaml
setup_bastion_registry: true
use_bastion_registry: true
```

If you run into any routing issues because of duplicate address detection, determine if someone else is using the same IPv6 subnet in the same lab environment and adjust accordingly.

If you previously deployed an IPv4 cluster and are switching to IPv6, stop and remove all running podman containers on the bastion and rerun the `setup-bastion.yml` playbook.

### Extra vars

The Extra vars section of `all.yml` is where you place any variable overrides for your deployment. All overrides should go in this section to keep configuration organized.

**Install Disk Configuration:**

For most common hardware types, Jetlag **automatically selects** the correct install disk using persistent `/dev/disk/by-path/` references. These automatic mappings are defined in `ansible/vars/lab.yml` under `hw_install_disk`.

Tested hardware includes:
- **Scale Lab:** r750, r660, r650, r640, r630
- **Performance Lab:** r740xd, r750, r7425, r7525, r760, 6029p, xe8640, xe9680

You **only need to set** `control_plane_install_disk` and `worker_install_disk` if:
- Your hardware model is not in the automatic mappings
- You need a different disk than the default for your hardware model
- You want to explicitly override the automatic selection

Please refer to [tips and vars](tips-and-vars.md#install-disk-by-path-vars) for the complete list of automatic mappings and guidance on finding disk paths for unlisted hardware.

## Review vars `all.yml`

The `ansible/vars/all.yml` now resembles ..

```yaml
---
# Sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Which lab to be deployed into (Ex scalelab, performancelab)
lab: scalelab
# Which cloud in the lab environment (Ex cloud42)
lab_cloud: cloud99

# Either mno or sno
cluster_type: mno

# Applies to mno clusters
worker_node_count: 2

# Set ocp_build to "ga", `dev`, or `ci` to pick a specific nightly build
ocp_build: "ga"

# ocp_version is used in conjunction with ocp_build
# For "ga" builds, examples are "latest-4.22", "latest-4.21", "4.22.1" or "4.21.7"
# For "dev" builds, examples are "candidate-4.22", "candidate-4.21" or "latest"
# For "ci" builds, an example is "4.19.0-0.nightly-2025-02-25-035256"
ocp_version: "latest-4.22"

# Set to true ONLY if you have a public routable vlan in your scalelab or performancelab cloud.
# Autoconfigures cluster_name, base_dns_name, controlplane_network_interface_idx, controlplane_network,
# controlplane_network_prefix, and controlplane_network_gateway to the values required for your cloud's public VLAN.
# SNO configures only the first cluster on the api dns resolvable address
# MNO/SNO still requires the correct value for bastion_controlplane_interface
# It is required to comment out controlplane_network and controlplane_network_prefix in the Network Configuration
public_vlan: false

# SNOs only require a single IP address and can be deployed using the lab DHCP interface instead of a private or
# public vlan network. Set to true to have your SNO deployed on the public lab DHCP network.
# Cannot combine public_vlan and sno_use_lab_dhcp
sno_use_lab_dhcp: false

# Enables FIPs security standard
enable_fips: false

#Enables the TechPreviewNoUpgrade feature set
enable_techpreview: false

# Enables Operators CNV and LSO install at deployment timeframe (GA releases only)
enable_cnv_install: false

ssh_private_key_file: ~/.ssh/id_rsa
ssh_public_key_file: ~/.ssh/id_rsa.pub
# Place your pull-secret.txt in the base directory of the cloned Jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull-secret.txt
pull_secret: "{{ lookup('file', '../pull-secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

smcipmitool_url:

# Network interfaces - these will be auto-configured based on lab and machine type
# if not explicitly set. To override auto-configuration, uncomment and set values:
# bastion_lab_interface: eno1np0
# bastion_controlplane_interface: ens1f0

# Sets up Gogs a self-hosted git service on the bastion
setup_bastion_gogs: false

# Set to enable and sync container images into a container image registry on the bastion
setup_bastion_registry: false

# Use in conjunction with ipv6 based clusters
use_bastion_registry: false

# Set to enable a forward proxy (Squid) for IPv6 clusters to access external registries
# This is an alternative to setup_bastion_registry - use one or the other
# When enabled, cluster nodes use the proxy to reach quay.io, registry.redhat.io, etc.
setup_bastion_proxy: false

# Reset iDRAC service using badfish container (pulls and uses badfish container
# to clear job queue and reset iDRAC service)
# reset_idrac: false

# Setup Hypervisor metrics collection for VMNO deployments
# Sets up Prometheus server on a bastion node and node_exporter on hypervisors
# Grafana is exposed at http://<bastion_fqdn>:3000 by default
# Prometheus is exposed on port 9090 instead
# For more configuration options, see ansible/roles/hv-metrics-server/defaults/main.yaml
# Do not override the role, just put override below
setup_hv_metrics: false

################################################################################
# OCP node vars
################################################################################
# Network configuration for all mno/sno cluster nodes
# This will be auto-configured based on lab and machine type if not explicitly set
# To override auto-configuration, uncomment and set value:
# controlplane_lab_interface: eno1np0

# Bond configuration for private network (optional for scale/performance labs)
# Enable bonding for bastion, controlplane, and worker nodes using 802.3ad mode
# When enabled, uses the first two network interfaces by default (indices 1 & 2)
# Only works with private VLANs (public_vlan: false) and homogeneous hardware
enable_bond: false

# VLAN subinterface on bond configuration (requires enable_bond: true)
# Enable VLAN subinterface on top of bond0 interface
# When enabled, creates bond0.<vlan_id> interface with specified VLAN tag
enable_bond_vlan: false
# VLAN ID for the subinterface (1-4094)
bond_vlan_id: 10
# Name for the VLAN subinterface (defaults to bond0.<vlan_id>)
# bond_vlan_interface_name: bond0.10

################################################################################
# Network Configuration
################################################################################
# Network variables default to single-stack IPv4 values via role defaults in
# ansible/roles/create-inventory/defaults/main/networks.yml
# Only uncomment and set these if you need to override the defaults
# (e.g., for IPv6 single stack or dual stack configurations).
#
# When public_vlan is enabled, these are auto-configured - do NOT set them.

# Single Stack IPv4 (default - no need to uncomment for standard deployments):
# controlplane_network:
# - 198.18.0.0/16
#
# controlplane_network_prefix:
# - 16
#
# cluster_network_cidr:
# - 10.128.0.0/14
#
# cluster_network_host_prefix:
# - 23
#
# service_network_cidr:
# - 172.30.0.0/16

# Single Stack IPv6:
# controlplane_network:
# - fd00:198:18:10::/64
#
# controlplane_network_prefix:
# - 64
#
# cluster_network_cidr:
# - fd01::/48
#
# cluster_network_host_prefix:
# - 64
#
# service_network_cidr:
# - fd02::/112
#
# Note: In IPv6-only configurations, IPv6 addresses are stored in the 'ip' field
# in the generated inventory (not 'ipv6'). The 'ipv6' field is only used for
# dual-stack configurations. CoreDNS templates automatically detect whether the
# 'ip' field contains an IPv4 or IPv6 address and generate appropriate DNS records.

# Dual Stack (IPv4 + IPv6):
# All network variables must be lists with two elements [IPv4, IPv6].
# First element must be IPv4, second must be IPv6.
#
# controlplane_network:
# - 198.18.0.0/16
# - fd00:198:18:10::/64
#
# controlplane_network_prefix:
# - 16
# - 64
#
# cluster_network_cidr:
# - 10.128.0.0/14
# - fd01::/48
#
# cluster_network_host_prefix:
# - 23
# - 64
#
# service_network_cidr:
# - 172.30.0.0/16
# - fd02::/112

################################################################################
# Extra vars
################################################################################
# Append override vars below

# Pre-GA content section
use_prega_content: false
# prega_idms_link: ""
```

## Run playbooks

Run the create inventory playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
...
```

The `create-inventory.yml` playbook will create an inventory file `ansible/inventory/cloud99.local` from the lab allocation data and the vars file.

The inventory file resembles ...

```
[all:vars]
allocation_node_count=16
supermicro_nodes=False

[bastion]
xxx-h01-000-r650.example.com ansible_ssh_user=root bmc_address=mgmt-xxx-h01-000-r650.example.com lab_ip=10.1.x.x

[bastion:vars]
bmc_user=quads
bmc_password=XXXXXXX

[controlplane]
xxx-h02-000-r650 bmc_address=mgmt-xxx-h02-000-r650.example.com mac_address=b4:96:91:cb:ec:02 lab_mac=5c:6f:69:75:c0:70 ip=198.18.0.5 vendor=Dell install_disk=/dev/sda
xxx-h03-000-r650 bmc_address=mgmt-xxx-h03-000-r650.example.com mac_address=b4:96:91:cc:e5:80 lab_mac=5c:6f:69:56:dd:c0 ip=198.18.0.6 vendor=Dell install_disk=/dev/sda
xxx-h05-000-r650 bmc_address=mgmt-xxx-h05-000-r650.example.com mac_address=b4:96:91:cc:e6:40 lab_mac=5c:6f:69:56:b0:50 ip=198.18.0.7 vendor=Dell install_disk=/dev/sda

[controlplane:vars]
role=master
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno12399np0
network_interface=eth0
network_prefix=24
gateway=198.18.0.1
dns1=198.18.0.1

[worker]
xxx-h06-000-r650 bmc_address=mgmt-xxx-h06-000-r650.example.com mac_address=b4:96:91:cc:e7:00 lab_mac=5c:6f:69:56:b1:10 ip=198.18.0.8 vendor=Dell install_disk=/dev/sda
xxx-h07-000-r650 bmc_address=mgmt-xxx-h07-000-r650.example.com mac_address=b4:96:91:cc:e7:c0 lab_mac=5c:6f:69:56:b2:20 ip=198.18.0.9 vendor=Dell install_disk=/dev/sda

[worker:vars]
role=worker
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno12399np0
network_interface=eth0
network_prefix=24
gateway=198.18.0.1
dns1=198.18.0.1

[sno]
# Unused

[sno:vars]
# Unused

[hv]
# Set `hv_inventory: true` to populate

[hv:vars]
# Set `hv_inventory: true` to populate

[hv_vm]
# Set `hv_inventory: true` to populate

[hv_vm:vars]
# Set `hv_inventory: true` to populate
```

Next run the `setup-bastion.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
...
```

Finally run the `mno-deploy.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
...
```

## Monitor install and interact with cluster

It is suggested to monitor your first deployment to see if anything hangs on boot or if the virtual media is incorrect according to the bmc. You can monitor your deployment by opening the bastion's GUI to assisted-installer (port 8080, ex `xxx-h01-000-r650.example.com:8080`), opening the consoles via the bmc of each system, and once the machines are booted, you can directly ssh to them and tail log files.

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion via the kubeconfig or kubeadmin password.

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/mno/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
NAME               STATUS   ROLES                         AGE    VERSION
xxx-h02-000-r650   Ready    control-plane,master          73m    v1.25.7+eab9cc9
xxx-h03-000-r650   Ready    control-plane,master          103m   v1.25.7+eab9cc9
xxx-h05-000-r650   Ready    control-plane,master          105m   v1.25.7+eab9cc9
xxx-h06-000-r650   Ready    worker                        68m    v1.25.7+eab9cc9
xxx-h07-000-r650   Ready    worker                        67m    v1.25.7+eab9cc9
(.ansible) [root@<bastion> jetlag]# cat /root/mno/kubeadmin-password
xxxxx-xxxxx-xxxxx-xxxxx
```
