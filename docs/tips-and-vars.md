# Jetlag Tips and additional Vars

_**Table of Contents**_

<!-- TOC -->
- [Override lab ocpinventory json file](#override-lab-ocpinventory-json-file)
- [DU Profile for SNOs](#du-profile-for-snos)
- [Post Deployment Tasks](#post-deployment-tasks)
- [Updating the OCP version](#updating-the-ocp-version)
<!-- /TOC -->

## Override lab ocpinventory json file

Current jetlag lab use selects machines for roles bastion, control-plane, and worker in that order from the ocpinventory.json file. You may have to create a new json file with the desired order to match desired roles if the auto selection is incorrect. After creating a new json file, host this where your machine running the playbooks can reach and set the following var such that the modified ocpinventory json file is used:

```yaml
ocp_inventory_override: http://example.redhat.com/cloud12-inventories/cloud12-cp_r640-w_5039ms.json
```
## DU Profile for SNOs

Use var `du_profile` to apply the DU specific machine configurations to your SNOs. Append the var to the "Extra vars" section of your `all.yml` or `ibmcloud.yml`.

```yaml
du_profile: true
```
As a result, the following machine configuration files will be added to the cluster during SNO install:
* 01-container-mount-ns-and-kubelet-conf-master.yaml 
* 03-sctp-machine-config-master.yaml
* 04-accelerated-container-startup-master.yaml
* 05-chrony-dynamic-master.yaml

In addition, Network Diagnostics will be disabled post SNO install.

Refer to https://github.com/openshift-kni/cnf-features-deploy/tree/master/ztp/source-crs for config details.

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

### Installing Performance Addon Operator

Append these vars to the "Extra vars" section of your `all.yml` or `ibmcloud.yml` to install Performance Addon Operator to allow for low latency node performance tunings on your cluster.

```yaml
install_performance_addon_operator: true
```

**Please Note**
* This feature is available for GA releases of OCP only
* You must define `reserved_cpus` in the vars file when installing Performance Addon Operator on Single Node Openshift clusters
* The workload partitioning CPUs (`reserved_cpus`) should match the reserved cpu specs within your performance-profile

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

Example settings of `reserved_cpus`:

```yaml
install_performance_addon_operator: true
reserved_cpus: 0-1,40-41
```

#### Performance Profile vars

The following vars are relevant to performance profile creation post SNO install:

```yaml
# Required vars
install_performance_addon_operator: true
# The reserved and isolated CPU pools must not overlap and together must span all available cores in the worker node.
reserved_cpus: 0-1,48-49
isolated_cpus: 2-47,50-95

#Optional vars

# If you want to install real-time kernel:
kernel_rt: true

# Number of hugepages of size 1G to be allocated on the SNO
hugepages_count: 16

# Kubelet Topology Manager Policy of the performance profile to be created. [Valid values: single-numa-node, best-effort, restricted] (default "restricted")
topology_manager_policy: best-effort
```

## Updating the OCP version

Versions are controlled by the release image. If you want to change images:

Modify the vars file to update release image path with `ocp_release_image` and the openshift version with `openshift_version`
Example:

```yaml
ocp_release_image: registry.ci.openshift.org/ocp/release:4.10.0-0.nightly-2022-01-18-044014
openshift_version: "4.10"
```
Ensure that your pull secrets are still valid.
When worikng with OCP development builds/nightly releases, it might be required to update your pull secret with fresh `registry.ci.openshift.org` credentials as they are bound to expire after a definite period. Follow these steps to update your pull secret:
* Login to https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/ with your github id. You must be a member of Openshift Org to do this.
* Select *Copy login command* from the drop-down list under your account name
* Copy the oc login command and run it on your terminal
* Execute the command shown below to print out the pull secret:

```console
[user@fedora jetlag]$ oc registry login --to=-
```
* Append or update the pull secret retrieved from above under pull_secret.txt in repo base directory.

You must stop and remove all assisted-installer containers on the bastion with [clean the pods and containers off the bastion](troubleshooting.md#cleaning-all-podscontainers-off-the-bastion-machines) and then rerun the setup-bastion step in order to setup your bastion's assisted-installer to the version you specified before deploying a fresh cluster with that version.
