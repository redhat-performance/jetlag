# Jetlag Tips and additional Vars

_**Table of Contents**_
<!-- TOC -->
- [Network interface to vars table](#network-interface-to-vars-table)
- [Override lab ocpinventory json file](#override-lab-ocpinventory-json-file)
- [DU Profile for SNOs](#du-profile-for-snos)
- [Post Deployment Tasks](#post-deployment-tasks)
- [Updating the OCP version](#updating-the-ocp-version)
- [Add/delete contents to the bastion registry](#add-delete-contents-to-the-bastion-registry)
- [Using other network interfaces](#using-other-network-interfaces)
- [Configuring NVMe install and etcd disks](#configuring-nvme-install-and-etcd-disks)
<!-- /TOC -->


## Network interface to vars table

Values here reflect the default (Network 1 which maps to `controlplane_network_interface_idx: 0`). See this [section](#using-other-network-interfaces) to generate the proper inventory for a different network.

**Scale Lab**

| Hardware           | bastion_lab_interface | bastion_controlplane_interface | controlplane_lab_interface |
| ------------------ | --------------------- | ------------------------------ | -------------------------- |
| Dell r660          | eno12399np0           | ens1f0                         | eno12399np0                |
| Dell r650          | eno12399np0           | ens1f0                         | eno12399np0                |
| Dell r640          | eno1np0               | ens1f0                         | eno1np0                    |
| Dell fc640         | eno1                  | eno2                           | eno1                       |
| Supermicro 1029p   | eno1                  | ens2f0                         | eno1                       |
| Supermicro 5039ms  | enp2s0f0              | enp1s0f0                       | enp2s0f0                   |

Scale lab chart is available [here](http://docs.scalelab.redhat.com/trac/scalelab/wiki/ScaleLabTipsAndTricks#RDU2ScaleLabPrivateNetworksandInterfaces).

**Performance Lab**

| Hardware           | bastion_lab_interface | bastion_controlplane_interface | controlplane_lab_interface |
| ------------------ | --------------------- | ------------------------------ | -------------------------- |
| Dell r740xd        | eno3                  | eno1                           | eno3                       |
| Dell r7425         | eno3                  | eno1                           | eno3                       |
| Dell r7525         | eno1                  | enp33np0                       | eno1                       |
| Dell r750          | eno8303               | ens3f0                         | eno8303                    |
| Supermicro 6029p   | eno1                  | enp95s0f0                      | eno1                       |

Performance lab chart is available [here](https://wiki.rdu3.labs.perfscale.redhat.com/usage/#Private_Networking).

## Extra vars for by-path disk reference
**Note:** For bare-metal deployment of OCP 4.13 or greater it is advisable to
set the extra vars for by-path reference for the installation as sometimes disk
names get swapped during boot discovery (e.g., sda and sdb). Using the PCI
paths (in a homogeneous SCALE or ALIAS lab cloud) should be consistent across
all the machines, and isn't subject to change during discovery. Below are the
extra vars along with the hardware used.

You can also set `sno_install_disk` for SNO deployments.

If the machine configurations in your cloud are not homogeneous, you'll need to
edit the inventory file to set appropriate install paths for each machine.

*NOTE*: Editing your inventory file is not recommended unless absolutely
necessary, as you won't be able to use the `create-inventory.yml` playbook again
without overwriting your customizations!

**Scale Lab**

| Hardware | Install disk | Install disk path
| -------- | ------------ | ----------------- |
| Dell r650 | sda | /dev/disk/by-path/pci-0000:67:00.0-scsi-0:2:0:0 |
| Dell r640 | sda | /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0 |

**Alias Lab**

| Hardware | Install disk | Install disk path
| - | - | - |
| Dell r740xd | sda | /dev/disk/by-path/pci-0000:86:00.0-scsi-0:2:0:0 |
| Dell r750 | sdk | /dev/disk/by-path/pci-0000:05:00.0-ata-1 |

To find your machine's by-path reference:

1. Use the `lsblk` command to find the disk with the mounted `/boot` partition;
`sda` in this example.
2. Use `find` to find the PCI path to that disk, which in this example is
`/dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0`.

*NOTE*: this assumes that the bastion hardware configuration is homogeneous: in
a heterogeneous cluster you may need to execute these commands on each host in
your cloud, setting the `sno_install_disk` (or `control_plane_install_disk` and
`worker_install_disk`) paths manually for each host in the inventory file.

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

## Override lab ocpinventory json file

By default Jetlag selects machines for the roles bastion, control-plane, and worker in that order from the ocpinventory.json file. You can create a new json file with the desired order to match desired roles if the auto selection is incorrect. After creating a new json file, host this where your machine running the playbooks can reach and set the following var such that the modified ocpinventory json file is used:

```yaml
ocp_inventory_override: http://<http-server>/<inventory-file>.json
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

### Network Attachment Definition

Append these vars to the "Extra vars" section of your `all.yml` or `ibmcloud.yml` to add a Macvlan Network Attachment
Definition. This allows you to add an additional network to pods created in your cluster.

```yaml
setup_network_attachment_definition: true
net_attach_def_namespace: default
net_attach_def_name: net1
net_attach_def_interface: bond0
net_attach_def_range: 192.168.0.0/16
```

Modify `net_attach_def_interface` to the desired host interface in which you want the macvlan network to exist. Modify
`net_attach_def_range` to an ip range that does not conflict with any other test-bed address ranges.

To have a pod attach an interface to the additional network, add the following example metadata annotation:

```yaml
annotations:
  k8s.v1.cni.cncf.io/networks: '[{"name": "net1", "namespace": "default"}]'
```

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

**Please Note**
* Performance Addon Operator is not available in OCP 4.11 or higher. The PAO code was moved into the Node Tuning Operator in OCP 4.11

## Updating the OCP version

Set `ocp_build` to one of 'dev' (early candidate builds) or 'ga' for Generally Available versions of OpenShift. Empty value results in playbook failing with error message. Example of dev builds would be 'candidate-4.17', 'candidate-4.16 or 'latest' (which would point to the early candidate build of the latest in development release) and examples of 'ga' builds would  be explicit versions like '4.15.20' or '4.16.0' or you could also use things like latest-4.16 to point to the latest z-stream of 4.16. Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp for a list of available builds for 'ga' releases and https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview for a list of 'dev' releases.

Set `ocp_version` to the version of the openshift-installer binary, undefined or empty results in the playbook failing with error message. Values accepted depended on the build chosen ('ga' or 'dev'). For 'ga' builds some examples of what you can use are 'latest-4.13', 'latest-4.14' or explicit versions like 4.15.2 For 'dev' builds some examples of what you can use are 'candidate-4.16' or just 'latest'.

```yaml
ocp_version: "4.15.2"
ocp_build: "ga"
ocp_version: "4.15.2"
```
Ensure that your pull secrets are still valid.
When worikng with OCP development builds/nightly releases, it might be required to update your pull secret with fresh `registry.ci.openshift.org` credentials as they are bound to expire after a definite period. Follow these steps to update your pull secret:
* Login to https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/ with your github id. You must be a member of Openshift Org to do this.
* Select *Copy login command* from the drop-down list under your account name
* Copy the oc login command and run it on your terminal
* Execute the command shown below to print out the pull secret:

```console
(.ansible) [root@<bastion> jetlag]# oc registry login --to=-
```
* Append or update the pull secret retrieved from above under pull_secret.txt in repo base directory.

You must stop and remove all assisted-installer containers on the bastion with [clean the pods and containers off the bastion](troubleshooting.md#cleaning-all-podscontainers-off-the-bastion-machines) and then rerun the setup-bastion step in order to setup your bastion's assisted-installer to the version you specified before deploying a fresh cluster with that version.

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

## Using other network interfaces

If you want to use a NIC other than the default, you need to override the `controlplane_network_interface_idx` variable in the `Extra vars` section of `ansible/vars/all.yml` and run from the `create-inventory.yml` playbook.
In this example using nic `ens2f0` in a cluster of r650 nodes is shown.
1. Select which NIC you want to use instead of the default, in this example, `ens2f0`.
2. Look for your server model number in [your labs wiki page](http://docs.scalelab.redhat.com/trac/scalelab/wiki/ScaleLabTipsAndTricks#RDU2ScaleLabPrivateNetworksandInterfaces) then select the network you want configured as your primary network using the following mapping:

| Network | YAML variable |
| ------- | ------------- |
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

## Configuring NVMe install and etcd disks

If you require the install disk or etcd disk to be on a specific drive,
they can be specified directly through the vars file `all.yml`.

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

**Note:** The values seen in `/dev/disk/by-path` may differ between RHEL8 and RHEL9.
If your OpenShift version is based on RHEL9 (4.13+), you should install RHEL9 on the nodes
first to ensure the paths are correct.
eg: `/dev/sda` - Seen on Supermicro 1029U
```
RHEL8:
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1 -> ../../sda

RHEL9:
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1 -> ../../sda
lrwxrwxrwx. 1 root root  9 Feb  5 19:22 pci-0000:00:11.5-ata-1.0 -> ../../sda  <---- Use this one
```
