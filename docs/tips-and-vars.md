# Jetlag Tips and additional Vars

_**Table of Contents**_
<!-- TOC -->
- [Override lab ocpinventory json file](#override-lab-ocpinventory-json-file)
- [DU Profile for SNOs](#du-profile-for-snos)
- [Post Deployment Tasks](#post-deployment-tasks)
- [Updating the OCP version](#updating-the-ocp-version)
- [Add/delete contents to the disconnected registry](#Add/delete-contents-to-the-disconnected-registry)
- [Using Other Network Interfaces](#Other-Networks)
<!-- /TOC -->

## Override lab ocpinventory json file

Current jetlag lab use selects machines for roles bastion, control-plane, and worker in that order from the ocpinventory.json file. You may have to create a new json file with the desired order to match desired roles if the auto selection is incorrect. After creating a new json file, host this where your machine running the playbooks can reach and set the following var such that the modified ocpinventory json file is used:

```yaml
ocp_inventory_override: http://example.redhat.com/cloud12-inventories/cloud12-cp_r640-w_5039ms.json
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
* 99-master-workload-partitioning.yml

In addition to this, Network Diagnostics will be disabled, performance-profile and tunedPerformancePatch will be applied post SNO install (based on input vars defined - See **SNO DU Profile** section under [Post Deployment Tasks](#post-deployment-tasks)).

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

# If you want to install real-time kernel:
kernel_rt: true

# Number of hugepages of size 1G to be allocated on the SNO
hugepages_count: 16

# Kubelet Topology Manager Policy of the performance profile to be created. [Valid values: single-numa-node, best-effort, restricted] (default "restricted")
topology_manager_policy: best-effort
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

## Add/delete contents to the disconnected registry
There might be use-cases when you want to add and delete images to/from the disconnected registry. For example, for the single stack IPv6 disconnect deployment, you deployment cannot reach quay.io to get the image for your containers.  In this situation, you may use the ICSP (ImageContentSecurityPolicy) mechanism in conjuction with image mirroring. When the deployment requests an image on quay.io, cri-o will intercept the request, redirect and map it to an image on the local registry.
For example, this policy will map images on quay.io/XXX/client-server to the disconnected registry on perf176b, the bastion of this IPv6 disconnect cluster.
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
```yaml
oc image mirror -a /opt/registry/pull-secret-disconnected.txt perf176b.xxx.com:5000/XXX/client-server:<tag> --keep-manifest-list --continue-on-error=true
```
Once the image has succesfully mirrored onto the disconnect registry, your deployment will be able to create the container.

For image deletion, use the Docker V2 REST API to delete the object. Note that the deletion operation argument has to be an image's digest not image's tag. So if you mirrored your image by tag in the previous step, on deletion you have to get its digest first. The following is a convenient script that deletes an image by tag.

```yaml
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

## Other Networks
If you want to use a NIC other than the default, you need to override the `controlplane_network_interface_idx` variable in the `Extra vars` section of `ansible/vars/all.yml`. 
In this example using nic `ens2f0` in a cluster of r650 nodes is shown.
1. Select which NIC you want to use instead of the default, in this example, `ens2f0`.
2. Look for your server model number in [your labs wiki page](http://docs.scalelab.redhat.com/trac/scalelab/wiki/ScaleLabTipsAndTricks#RDU2ScaleLabPrivateNetworksandInterfaces) then select the network you want configured as your primary network using the following mapping
```
* Network 1 = `controlplane_network_interface_idx: 0`
* Network 2 = `controlplane_network_interface_idx: 1`
* Network 3 = `controlplane_network_interface_idx: 2`
* Network 4 = `controlplane_network_interface_idx: 3`
* Network 5 = `controlplane_network_interface_idx: 4`
```
3. Since the desired NIC in this exampls,`ens2f0`, is listed under the column "Network 3" the value **2** is correct.
4. Set **2** as the value of the variable `controlplane_network_interface_idx` in `ansible/vars/all.yaml`. 
```
################################################################################
# Extra vars
################################################################################
# Append override vars below
controlplane_network_interface_idx: 2
```
### Alternative method
In case you are bringing your own lab, set `controlplane_network_interface` to the desired name, eg. `controlplane_network_interface: ens2f0`.
