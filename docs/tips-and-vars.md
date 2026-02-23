# Jetlag Tips and additional Vars

_**Table of Contents**_
<!-- TOC -->
- [Jetlag Tips and additional Vars](#jetlag-tips-and-additional-vars)
  - [Network interface to vars table](#network-interface-to-vars-table)
  - [Install disk by-path vars](#install-disk-by-path-vars)
  - [Updating the OCP version](#updating-the-ocp-version)
  - [Override lab ocpinventory json file](#override-lab-ocpinventory-json-file)
  - [Using other network interfaces](#using-other-network-interfaces)
    - [Alternative method](#alternative-method)
    - [Bonding in the scale/perf labs](#bonding-in-the-scaleperf-labs)
  - [Configuring NVMe install and etcd disks](#configuring-nvme-install-and-etcd-disks)
  - [DU Profile for SNOs](#du-profile-for-snos)
  - [Post Deployment Tasks](#post-deployment-tasks)
    - [SNO DU Profile](#sno-du-profile)
      - [Performance Profile](#performance-profile)
      - [Tuned Performance Patch](#tuned-performance-patch)
      - [Installing Performance Addon Operator on OCP 4.9 or OCP 4.10](#installing-performance-addon-operator-on-ocp-49-or-ocp-410)
  - [Add/delete contents to the bastion registry](#adddelete-contents-to-the-bastion-registry)
<!-- /TOC -->


## Network interface to vars table

**Network interfaces** - Jetlag automatically detects and configures network interfaces for common hardware in Scale Lab and Performance Lab using the `hw_nic_name` [mapping](../ansible/vars/lab.yml). You only need to manually set these if you want to override the defaults:
- `bastion_lab_interface` - the bastion machine's lab accessible interface
- `bastion_controlplane_interface` - the bastion machine interface connected to the OCP cluster nodes control plane
- `controlplane_lab_interface` - the OCP cluster nodes lab accessible interface

Values here reflect the default (Network 1 which maps to `controlplane_network_interface_idx: 0`). See this [section](#using-other-network-interfaces) to generate the proper inventory for a different network.

**Scale Lab**

| Hardware          | bastion_lab_interface | bastion_controlplane_interface | controlplane_lab_interface |
| ----------------- | --------------------- | ------------------------------ | -------------------------- |
| Dell r660         | eno12399np0           | ens1f0                         | eno12399np0                |
| Dell r650         | eno12399np0           | ens1f0                         | eno12399np0                |
| Dell r640         | eno1np0               | ens1f0                         | eno1np0                    |
| Dell r630         | enp3s0f0              | eno1                           | enp3s0f0                   |
| Dell fc640        | eno1                  | eno2                           | eno1                       |
| Supermicro 1029p  | eno1                  | ens2f0                         | eno1                       |
| Supermicro 5039ms | enp2s0f0              | enp1s0f0                       | enp2s0f0                   |

Scale lab network table is available on the scale lab wiki.

**Performance Lab**

| Hardware         | bastion_lab_interface | bastion_controlplane_interface | controlplane_lab_interface |
| ---------------- | --------------------- | ------------------------------ | -------------------------- |
| Dell r740xd      | eno3                  | eno1                           | eno3                       |
| Dell r7425       | eno3                  | eno1                           | eno3                       |
| Dell r7525       | eno1                  | enp33np0                       | eno1                       |
| Dell r750        | eno8303               | ens3f0                         | eno8303                    |
| Supermicro 6029p | eno1                  | enp95s0f0                      | eno1                       |

Performance lab network table is available on the performance lab wiki.

## Install disk by-path vars

Setting the install disk to use a by-path link is required for multi-disk systems as a
symbolic link can change which underlying disk is referenced and may refer to a
non-bootable disk or disk later in the boot order of hard disks. If this occurs, the
deployment will eventually fail as the installed OCP is unable to boot properly.

> [!TIP]
> **Automatic Install Disk Selection:** For common hardware types in Scale Lab and Performance Lab,
> Jetlag automatically selects the correct install disk using persistent `/dev/disk/by-path/`
> references based on hardware model. See `hw_install_disk` mappings in `ansible/vars/lab.yml`.
>
> The automatic selection uses a fallback chain:
> 1. Explicit variable override (`control_plane_install_disk`, `worker_install_disk`, `sno_install_disk`)
> 2. Rack-unit-hardware specific mapping (e.g., `y37-h01-r740xd`)
> 3. Rack-hardware specific mapping (e.g., `y37-r740xd`)
> 4. Hardware default mapping (e.g., `r740xd`)
> 5. Fallback to `/dev/sda`

**When to override:** You typically only need to set `control_plane_install_disk`,
`worker_install_disk`, or `sno_install_disk` if:
- Your hardware model is not in the automatic mappings
- You need a different disk than the default for your hardware
- You are using BYOL (Bring Your Own Lab) outside of Scale/Performance labs

For 3-node MNO deployments you only need to set `control_plane_install_disk`, if your
MNO deployment has worker nodes then you will also need to set `worker_install_disk`.

For SNO deployments set `sno_install_disk`. If you scale out your SNO deployment with worker nodes then you will also need to set `worker_install_disk`.

If the machine configurations in your cloud are not homogeneous, you will need to
edit the inventory file to set appropriate install paths for each machine.

> [!CAUTION]
> Editing your inventory file is not recommended unless absolutely necessary, as
> you will not be able to use the `create-inventory.yml` playbook again without
> overwriting your customizations!

**Scale Lab**

| Hardware  | Install disk path                               |
| --------- | ----------------------------------------------- |
| Dell r750 | /dev/disk/by-path/pci-0000:05:00.0-ata-1.0      |
| Dell r660 | /dev/disk/by-path/pci-0000:4a:00.0-scsi-0:0:1:0 |
| Dell r650 | /dev/disk/by-path/pci-0000:67:00.0-scsi-0:2:0:0 |
| Dell r640 | /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0 |
| Dell r630 | /dev/disk/by-path/pci-0000:02:00.0-scsi-0:2:0:0 |

**Performance Lab**

| Hardware                                             | Install disk path                               |
| ---------------------------------------------------- | ----------------------------------------------- |
| Dell r740xd (SL-N, SL-G, SL-U, CL-N, CL-U-2, CL-G-2) | /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0 |
| Dell r740xd (CL-U-1, CL-G-1)                         | /dev/disk/by-path/pci-0000:86:00.0-scsi-0:2:0:0 |
| Dell r750                                            | /dev/disk/by-path/pci-0000:05:00.0-ata-1        |
| Dell r7425                                           | /dev/disk/by-path/pci-0000:e2:00.0-scsi-0:2:0:0 |
| Dell r7525                                           | /dev/disk/by-path/pci-0000:01:00.0-scsi-0:2:0:0 |
| Dell r760                                            | /dev/disk/by-path/pci-0000:3f:00.0-scsi-0:0:1:0 |
| SuperMicro 6029p                                     | /dev/disk/by-path/pci-0000:00:11.5-ata-5        |
| Dell xe8640                                          | /dev/disk/by-path/pci-0000:01:00.0-nvme-1       |
| Dell xe9680                                          | /dev/disk/by-path/pci-0000:01:00.0-nvme-1       |

> [!NOTE]
> The above hardware models are automatically configured in Jetlag via the `hw_install_disk`
> mappings in `ansible/vars/lab.yml`. You typically do not need to manually set install
> disk variables for these common hardware types unless you need to override the defaults.

To find your machine's by-path reference:

1. Use the `lsblk` command to find the disk with the mounted `/boot` partition;
`sda` in this example.
2. Use `find` to find the PCI path to that disk, which in this example is
`/dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0`.

> [!TIP]
> You can use use [this playbook](https://github.com/sadsfae/ansible-dbp) to generate a YAML file with all of your systems `/dev/disk/by-path` for every detected disk.  Ideally run this when you first receive machines if you are using a [QUADS-managed](https://github.com/redhat-performance/quads) lab.

> [!WARNING]
> This assumes that the bastion hardware configuration is homogeneous: in
> a heterogeneous cluster you may need to execute these commands on each host in
> your cloud, setting the `sno_install_disk` (or `control_plane_install_disk` and
> `worker_install_disk`) paths manually for each host in the inventory file.

```console
(.ansible) [root@<bastion> jetlag]# lsblk
NAME                                MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                                   8:0    0  1.7T  0 disk
├─sda1                                8:1    0    1G  0 part /boot
└─sda2                                8:2    0  1.7T  0 part
  ├─rhel_y37--h27--000--r740xd-root 253:0    0   70G  0 lvm  /
  └─rhel_y37--h27--000--r740xd-swap 253:1    0    4G  0 lvm  [SWAP]
sdb                                   8:16   0  1.7T  0 disk
sdc                                   8:32   0  1.7T  0 disk
sdd                                   8:48   0  1.7T  0 disk
└─sdd1                                8:49   0  1.7T  0 part
sde                                   8:64   0  1.7T  0 disk
sdf                                   8:80   0  1.7T  0 disk
sdg                                   8:96   0  1.7T  0 disk
sdh                                   8:112  0  1.7T  0 disk
nvme0n1                             259:0    0  1.5T  0 disk
(.ansible) [root@<bastion> jetlag]# find /dev/disk/by-path -lname \*sda
/dev/disk/by-path/pci-0000:86:00.0-scsi-0:2:0:0
```

You can also identify your machine's specific type by logging into the lab's foreman instance, viewing all your hosts and enabling the "model" field to show which type by host is in your cloud allocation.

## Updating the OCP version

Set `ocp_build` to `ga` for Generally Available versions, `dev` (early candidate builds)
of OpenShift, or `ci` to pick a specific nightly build. Empty value results in playbook
failing with an error message. `ocp_version` is used in conjunction with `ocp_build`.
Examples of `ocp_version` with `ocp_build: ga` include explicit versions such as
`4.17.17` or `4.16.35`, additionally `latest-4.17` or `latest-4.16` point to the latest
z-stream of 4.17 and 4.16 ga builds. Examples of `ocp_version` with `ocp_build: dev`
are `candidate-4.17`, `candidate-4.16` or `latest` which points to the early candidate
build of the latest in development release. Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp/
for a list of available builds for `ga` releases and https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview/
for a list of `dev` releases. Nightly `ci` builds are tricky and require determining
exact builds you can use, an example of `ocp_version` with `ocp_build: ci` is `4.19.0-0.nightly-2025-02-25-035256`, For 'ci' builds check latest nightly from  https://amd64.ocp.releases.ci.openshift.org/.


```yaml
ocp_build: "ga"
ocp_version: "4.17.17"
```

Ensure that your pull secrets are still valid.
When working with OCP development build or nightly release, it might be required to update your pull secret with fresh `registry.ci.openshift.org` credentials as they expire after a finite period. Follow these steps to update your pull secret:
* Login to https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/ with your github id. You must be a member of OpenShift Org to do this.
* Select *Copy login command* from the drop-down list under your account name
* Copy the oc login command and run it on your terminal
* Execute the command shown below to print out the pull secret:

```console
(.ansible) [root@<bastion> jetlag]# oc registry login --to ci_ps.json
info: Using registry public hostname registry.ci.openshift.org
Saved credentials for registry.ci.openshift.org into ci_ps.json
(.ansible) [root@<bastion> jetlag]# cat ci_ps.json
{
	"auths": {
		"registry.ci.openshift.org": {
			"auth": "xxxxxxxxxxxxxxxxxxxxxxxxxxx"
		}
	}
}
```
* Append or update the pull secret retrieved from above under pull-secret.txt in repo base directory.

You must stop and remove all assisted-installer containers on the bastion with [clean the pods and containers off the bastion](troubleshooting.md#cleaning-all-podscontainers-off-the-bastion-machines) and then rerun the setup-bastion step in order to setup your bastion's assisted-installer to the version you specified before deploying a fresh cluster with that version.

## Override lab ocpinventory json file

By default Jetlag selects machines for the roles bastion, control-plane, and worker in that order from the ocpinventory.json file. You can create a new json file with the desired order to match desired roles if the auto selection is incorrect. After creating a new json file, host this where your machine running the playbooks can reach and set the following var such that the modified ocpinventory json file is used, or specify a local path for the file:

```yaml
ocp_inventory_override: http://<http-server>/<inventory-file>.json

# or

ocp_inventory_override: <LOCAL_FILE_PATH>
```

## Using other network interfaces

If you want to use a NIC other than the default, you need to override the `controlplane_network_interface_idx` variable in the `Extra vars` section of `ansible/vars/all.yml` and run from the `create-inventory.yml` playbook.
In this example using nic `ens2f0` in a cluster of r650 nodes is shown.
1. Select which NIC you want to use instead of the default, in this example, `ens2f0`.
2. Look for your server model number in your lab's network table/chart then select the network you want configured as your primary network using the following mapping:

| Network   | YAML variable                           |
| --------- | --------------------------------------- |
| Network 1 | `controlplane_network_interface_idx: 0` |
| Network 2 | `controlplane_network_interface_idx: 1` |
| Network 3 | `controlplane_network_interface_idx: 2` |
| Network 4 | `controlplane_network_interface_idx: 3` |
| Network 5 | `controlplane_network_interface_idx: 4` |

3. Since the desired NIC in this example,`ens2f0`, is listed under the column "Network 3" the value **2** is correct.
4. Set **2** as the value of the variable `controlplane_network_interface_idx` in `ansible/vars/all.yaml`.

```yaml
################################################################################
# Extra vars
################################################################################
# Append override vars below
controlplane_network_interface_idx: 2
```

### Alternative method
In case you are bringing your own lab, set `controlplane_network_interface` to the desired name, eg. `controlplane_network_interface: ens2f0`.

### Bonding in the scale/perf labs
To support some particular use cases jetlag implements the option for LACP bonding through the var `enable_bond`.
When enabled, uses the first two network interfaces by default (indices 1 & 2).
Only works with private networks (`public_vlan: false`) and homogeneous hardware.
At the moment QUADS does not expose any APIs for this kind of networking setup in the labs, so unless you have discussed your particular use case with the DevOps team and the network setup of your cloud allocation is ready to accommodate this config, please disconsider this option.

#### VLAN subinterface on bonding
Additionally, you can enable VLAN subinterfaces on top of bond0 using the following configuration:

```yaml
enable_bond: true
enable_bond_vlan: true
bond_vlan_id: 10
# bond_vlan_interface_name: bond0.10  # Optional: defaults to bond0.<vlan_id>
```

This creates a VLAN subinterface (bond0.10) on top of the bond0 interface with the specified VLAN tag. The IP addresses are assigned to the VLAN subinterface instead of the bond0 interface directly.

**What this configures:**
- **Bastion host**: Creates bond0 (no IP) + bond0.10 (with controlplane IP) using nmcli
- **Cluster nodes**: Creates bond0 (no IP) + bond0.10 (with node IPs) using nmstate
- **Network routing**: All traffic flows through the VLAN subinterface

**Requirements:**
- `enable_bond` must be set to `true`
- `bond_vlan_id` must be between 1-4094
- Only works with private networks (`public_vlan: false`)
- Network infrastructure must support the specified VLAN tag

## Configuring NVMe install and etcd disks

If you require the install disk or etcd disk to be on a specific drive (different from
the automatic selections), they can be specified directly through the vars file `all.yml`.

This is typically used when:
- You want to install on NVMe drives instead of the default SATA/SAS disks
- You need to override the automatic hardware-based selection
- Your specific hardware configuration requires non-standard disk selection

To ensure the drive will be correctly mapped at each boot,
we will locate the `/dev/disk/by-path` link to each drive.

```console
# Locate names of the drives identified on your system
$ lsblk | grep nvme
nvme3n1     259:0    0   1.5T  0 disk
nvme2n1     259:1    0   1.5T  0 disk
nvme1n1     259:2    0   1.5T  0 disk
nvme0n1     259:3    0   1.5T  0 disk

# Find the corresponding disk/by-path link
$ ls -l /dev/disk/by-path/ | grep nvme
lrwxrwxrwx. 1 root root  13 Aug 21 17:34 pci-0000:b1:00.0-nvme-1 -> ../../nvme0n1
lrwxrwxrwx. 1 root root  13 Aug 21 17:34 pci-0000:b2:00.0-nvme-1 -> ../../nvme1n1
lrwxrwxrwx. 1 root root  13 Aug 21 17:34 pci-0000:b3:00.0-nvme-1 -> ../../nvme2n1
lrwxrwxrwx. 1 root root  13 Aug 21 17:34 pci-0000:b4:00.0-nvme-1 -> ../../nvme3n1
```

Add these values to your extra vars section in the `all.yml` file.

In this case we are installing on all NVMe drives,
and will have configured our hosts for UEFI boot.

`ansible/vars/all.yml`
```yaml
################################################################################
# Extra vars
################################################################################

# Install disks
# sno_install_disk: /dev/disk/by-path/...
control_plane_install_disk: /dev/disk/by-path/pci-0000:b1:00.0-nvme-1
worker_install_disk: /dev/disk/by-path/pci-0000:b1:00.0-nvme-1

# Control plane etcd deployed on NVMe
controlplane_nvme_device: /dev/disk/by-path/pci-0000:b2:00.0-nvme-1
controlplane_etcd_on_nvme: true
```

> [!WARNING]
> The values seen in `/dev/disk/by-path` may differ between RHEL8 and RHEL9.
> If your OpenShift version is based on RHEL9 (4.13+), you should install RHEL9 on the nodes
> first to ensure the paths are correct.
> eg: `/dev/sda` - Seen on Supermicro 1029U
```
RHEL8:
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1 -> ../../sda

RHEL9:
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1 -> ../../sda
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1.0 -> ../../sda  <---- Use this one
```

## DU Profile for SNOs

Use var `du_profile` to apply the DU specific machine configurations to your SNOs. You must also define `reserved_cpus` and `isolated_cpus` when applying DU profile. Append these vars to the "Extra vars" section of your `all.yml` or `ibmcloud.yml`.

Example settings:

```yaml
du_profile: true
# The reserved and isolated CPU pools must not overlap and together must span all available cores in the worker node.
reserved_cpus: 0-1,40-41
isolated_cpus: 2-39,42-79
```

As a result, the following machine configuration files will be added to the cluster during SNO install:
* 01-container-mount-ns-and-kubelet-conf-master.yaml
* 03-sctp-machine-config-master.yaml
* 04-accelerated-container-startup-master.yaml
* 05-kdump-config-master (when kdump is enabled)
* 99-crio-disable-wipe-master
* 99-master-workload-partitioning.yml
* enable-crun-master.yaml

When deploying DU profile on OCP 4.13 or higher, composable openshift feature will automatically be deployed and as a result, all unnecessary optional Cluster Operators will not be deployed.

In addition to this, Network Diagnostics will be disabled, monitoring footprint will be reduced, performance-profile and tunedPerformancePatch will be applied post SNO install (based on input vars defined - See **SNO DU Profile** section under [Post Deployment Tasks](#post-deployment-tasks)).

Refer to https://github.com/openshift-kni/cnf-features-deploy/tree/master/ztp/source-crs for config details.

**About Reserved CPUs**

Setting `reserved_cpus` would allow us to isolate the control plane services to run on a restricted set of CPUs.

You can reserve cores, or threads, for operating system housekeeping tasks from a single NUMA node and put your workloads on another NUMA node. The reason for this is that the housekeeping processes might be using the CPUs in a way that would impact latency sensitive processes running on those same CPUs. Keeping your workloads on a separate NUMA node prevents the processes from interfering with each other. Additionally, each NUMA node has its own memory bus that is not shared.

If you are unsure about which cpus to reserve for housekeeping-pods, the general rule is to identify any two processors and their siblings on separate NUMA nodes:

```console
# lscpu -e | head -n1
CPU NODE SOCKET CORE L1d:L1i:L2:L3 ONLINE MAXMHZ    MINMHZ

# lscpu -e |  egrep "0:0:0:0|1:1:1:1"
0   0    0      0    0:0:0:0       yes    3900.0000 800.0000
1   1    1      1    1:1:1:1       yes    3900.0000 800.0000
40  0    0      0    0:0:0:0       yes    3900.0000 800.0000
41  1    1      1    1:1:1:1       yes    3900.0000 800.0000
```

## Post Deployment Tasks

### SNO DU Profile

#### Performance Profile

The following vars are relevant to performance profile creation post SNO install:

```yaml
# Required vars
du_profile: true
# The reserved and isolated CPU pools must not overlap and together must span all available cores in the worker node.
reserved_cpus: 0-1,48-49
isolated_cpus: 2-47,50-95

#Optional vars

# Number of hugepages of size 1G to be allocated on the SNO
hugepages_count: 16
```

#### Tuned Performance Patch

After performance-profile is applied, the standard TunedPerformancePatch used for SNO DUs will also be applied post SNO install if DU profile is enabled.
This profile will disable chronyd service and enable stalld, change the FIFO priority of ice-ptp processes to 10.
Further changes applied can be found in the template 'tunedPerformancePatch.yml.j2' under sno-post-cluster-install templates.

#### Installing Performance Addon Operator on OCP 4.9 or OCP 4.10

Performance Addon Operator must be installed for the usage of performance-profile in versions older than OCP 4.11.
Append these vars to the "Extra vars" section of your `all.yml` or `ibmcloud.yml` to install Performance Addon Operator to allow for low latency node performance tunings on your OCP 4.9 or 4.10 SNO.

```yaml
install_performance_addon_operator: true
```

> [!NOTE]
> The Performance Addon Operator is not available in OCP 4.11 or higher. The PAO code was moved into the Node Tuning Operator in OCP 4.11

## Add/delete contents to the bastion registry

There might be use-cases when you want to add and delete images to/from the bastion registry. For example, for the single stack IPv6 disconnected deployment, the deployment cannot reach quay.io to get the image for your containers.  In this situation, you may use the ICSP (ImageContentSecurityPolicy) mechanism in conjunction with image mirroring. When the deployment requests an image on quay.io, cri-o will intercept the request, redirect and map it to an image on the bastion/mirror registry.
For example, this policy will map images on quay.io/XXX/client-server to the mirror registry on perf176b, the bastion of this IPv6 disconnected cluster.
```yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: crucible-repo
spec:
  repositoryDigestMirrors:
  - mirrors:
    - perf176b.xxx.com:5000/XXX/client-server
    source: quay.io/XXX/client-server
```

For on-demand mirroring, the next command run on the bastion will mirror the image from quay.io to perf176b's disconnected registry.

```console
(.ansible) [root@<bastion> jetlag]# oc image mirror -a /opt/registry/pull-secret-bastion.txt perf176b.xxx.com:5000/XXX/client-server:<tag> --keep-manifest-list --continue-on-error=true
```
Once the image has successfully mirrored onto the disconnected registry, your deployment will be able to create the container.

For image deletion, use the Docker V2 REST API to delete the object. Note that the deletion operation argument has to be an image's digest not image's tag. So if you mirrored your image by tag in the previous step, on deletion you have to get its digest first. The following is a convenient script that deletes an image by tag.

```console
### script
#!/bin/bash
registry='[fc00:1000::1]:5000'   <===== IPv6 address and port of perf176b disconnected registry
name='XXX/client-server'
auth='-u username:passwd'

function rm_XXX_tag {
 ltag=$1
 curl $auth -X DELETE -sI -k "https://${registry}/v2/${name}/manifests/$(
   curl $auth -sI -k \
     -H "Accept: application/vnd.oci.image.manifest.v1+json" \
      "https://${registry}/v2/${name}/manifests/${ltag}" \
   | tr -d '\r' | sed -En 's/^Docker-Content-Digest: (.*)/\1/pi'
 )"
}
```
