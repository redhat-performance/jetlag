# Deploy a Bare Metal cluster via jetlag quickstart

Assuming you received a scale lab allocation named `cloud99`, this guide will walk you through getting a bare-metal cluster up in your allocation. For purposes of the guide the systems in `cloud99` will be Supermicro 1029p.

## Prerequisites

Before you start with jetlag, there are a couple of things to be installed on the machine. These instructions are also on the [README](https://github.com/redhat-performance/jetlag#prerequisites).

Good practice when you get your lab allocation is to copy your ssh pubkey to the bastion and start with jetlag from there.

## Clone Jetlag

Clone jetlag on to your laptop and change to the jetlag directory

```console
[user@fedora ~]$ git clone https://github.com/redhat-performance/jetlag.git
Cloning into 'jetlag'...
remote: Enumerating objects: 1639, done.
remote: Counting objects: 100% (393/393), done.
remote: Compressing objects: 100% (210/210), done.
remote: Total 1639 (delta 233), reused 232 (delta 160), pack-reused 1246
Receiving objects: 100% (1639/1639), 253.01 KiB | 1.07 MiB/s, done.
Resolving deltas: 100% (704/704), done.
[user@fedora ~]$ cd jetlag
```

## Review Prerequisites and set pull-secret

Review the Ansible prerequisites on the [README](https://github.com/redhat-performance/jetlag#prerequisites).

Recommended: run ansible inside virtual environment: ```source bootstrap.sh```

Set your pull secret file `pull_secret.txt` in the base directory of the cloned jetlag repo. The contents should resemble this json:

```
[user@fedora jetlag]$ cat pull_secret.txt
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

If you are deploying nightly builds then you will need a ci token and an entry for `registry.ci.openshift.org`. If you plan on deploying an ACM downstream build be sure to include an entry for `quay.io:443`

## all.yml vars file

Next copy the vars file so we can edit it.

```console
[user@fedora jetlag]$ cp ansible/vars/all.sample.yml ansible/vars/all.yml
[user@fedora jetlag]$ vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: scalelab`

Change `lab_cloud` to `lab_cloud: cloud99`

Change `cluster_type` to `cluster_type: bm`

Set `worker_node_count` if you desire to limit the number of worker nodes from your scale lab allocation.

Change `ocp_release_image` to the desired image if the default (4.12.1) is not the desired version.
If you change `ocp_release_image` to a different major version (Ex `4.12`), then change `openshift_version` accordingly.

Only change `networktype` if you need to test something other than `OVNKubernetes`

For the ssh keys we have a chicken before the egg problem in that our bastion machine won't be defined or ensure that keys are created until after we run `create-inventory.yml` and `setup-bastion.yml` playbooks. We will revisit that a little bit later.

### Bastion node vars

The bastion node is usually the first node in an allocation.

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI).

The system type determines the values of `bastion_lab_interface` and `bastion_controlplane_interface`.

Using the chart provided by the [scale lab here](http://docs.scalelab.redhat.com/trac/scalelab/wiki/ScaleLabTipsAndTricks#RDU2ScaleLabPrivateNetworksandInterfaces), determine the names of the nic per network for EL8.

* `bastion_lab_interface` will always be set to the nic name under "Public Network"
* `bastion_controlplane_interface` should be set to the nic name under "Network 1" for this guide

You may have to ssh to your intended bastion machine and view the network interface names to ensure the correct nic name is picked here.

For example if your bastion is ...

Dell fc640
```yaml
bastion_lab_interface: eno1
bastion_controlplane_interface: eno2
```

Dell r640
```yaml
bastion_lab_interface: eno1np0
bastion_controlplane_interface: ens1f0
```

Dell r650
```yaml
bastion_lab_interface: eno12399np0
bastion_controlplane_interface: ens1f0
```

Supermicro 1029p
```yaml
bastion_lab_interface: eno1
bastion_controlplane_interface: ens2f0
```

Supermicro 5039ms
```yaml
bastion_lab_interface: enp2s0f0
bastion_controlplane_interface: enp1s0f0
```

For the guide we set our values for the Supermicro 1029p.

** If you desire to use a *different network* than "Network 1" for your controlplane network then you will have to append some additional overrides to the extra vars portion of the all.yml vars file.
See [tips and vars](https://github.com/redhat-performance/jetlag/blob/main/docs/tips-and-vars.md#Other-Networks) for more information

### OCP node vars

The same chart provided by the scale lab for the bastion machine, is used to identify the nic names for `controlplane_lab_interface`.

* `controlplane_lab_interface` should always be set to the nic name under "Public Network" for the specific system type

For example if your Bare Metal OpenShift systems are ...

Dell fc640
```yaml
controlplane_lab_interface: eno1
```

Dell r640
```yaml
controlplane_lab_interface: eno1np0
```

Dell r650
```yaml
controlplane_lab_interface: eno12399np0
```

Supermicro 1029p
```yaml
controlplane_lab_interface: eno1
```

Supermicro 5039ms
```yaml
controlplane_lab_interface: enp2s0f0
```

For the guide we set our values for the Supermicro 1029p.

** If your machine types are not homogeneous, then you will have to manually edit your generated inventory file to correct any nic names until this is reasonably automated.

### Extra vars

No extra vars are needed for an ipv4 bare metal cluster.

### Disconnected and ipv6 vars

If you want to deploy a disconnected ipv6 cluster then the following vars need to be set.

Change `use_disconnected_registry` to `use_disconnected_registry: true` under "Bastion node vars"

Append the following "override" vars in "Extra vars"

```yaml
controlplane_network: fc00:1000::/64
controlplane_network_prefix: 64
cluster_network_cidr: fd01::/48
cluster_network_host_prefix: 64
service_network_cidr: fd02::/112
fix_metal3_provisioningosdownloadurl: true
```

Oddly enough if you run into any routing issues because of duplicate address detection, determine if someone else is using subnet `fc00:1000::/64` in the same lab environment and adjust accordingly.

The completed `all.yml` vars file and generated inventory files following this section only reflect that of an ipv4 connected install. If you previously deployed ipv4 stop and remove all running podman containers off the bastion and rerun the `setup-bastion.yml` playbook.

## Review all.yml

The `ansible/vars/all.yml` now resembles ..

```yaml
---
# Sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Which lab to be deployed into (Ex scalelab)
lab: scalelab
# Which cloud in the lab environment (Ex cloud42)
lab_cloud: cloud99

# Either bm or rwn or sno
cluster_type: bm

# Applies to both bm/rwn clusters
worker_node_count:

# Applies to sno clusters
sno_node_count:

# Lab Network type, applies to sno cluster_type only
# Set this variable if you want to host your SNO cluster on lab public routable
# VLAN network, set this ONLY if you have public routable VLAN enabled in your
# scalelab cloud
public_vlan: false

# Versions are controlled by this release image. If you want to change images
# you must stop and rm all assisted-installer containers on the bastion and rerun
# the setup-bastion step in order to setup your bastion's assisted-installer to
# the version you specified
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.12.1-x86_64

# This should just match the above release image version (Ex: 4.12)
openshift_version: "4.12"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

ssh_private_key_file: ~/.ssh/id_rsa
ssh_public_key_file: ~/.ssh/id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned jetlag repo, Example:
# [user@fedora jetlag]$ ls pull_secret.txt
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

smcipmitool_url: http://example.lab.com/tools/SMCIPMITool_2.25.0_build.210326_bundleJRE_Linux_x64.tar.gz

bastion_lab_interface: eno1
bastion_controlplane_interface: ens2f0

# vlaned interfaces are for remote worker node clusters only
bastion_vlaned_interface: ens1f1

# Used in conjunction with ACM/ZTP disconnected hub clusters (ipv6 only at the moment)
setup_gogs: false

# Use in conjunction with ipv6 based clusters
use_disconnected_registry: false

################################################################################
# OCP node vars
################################################################################
# Network configuration for all bm cluster and rwn control-plane nodes
controlplane_lab_interface: eno1

# Network configuration for public VLAN based sno cluster_type deployment
controlplane_pub_network_cidr:
controlplane_pub_network_gateway:
jumbo_mtu: false

# Network only for remote worker nodes
rwn_lab_interface: eno1np0
rwn_network_interface: ens1f1

################################################################################
# Extra vars
################################################################################
# Append override vars below
```

## Run playbooks

Run the create inventory playbook

```console
[user@fedora jetlag]$ ansible-playbook ansible/create-inventory.yml
...
```

The `create-inventory.yml` playbook will create an inventory file `ansible/inventory/cloud99.local` from the lab allocation data and the vars file.

The inventory file resembles ...

```
[all:vars]
allocation_node_count=12

[bastion]
f16-h11-000-1029p.rdu2.scalelab.redhat.com ansible_ssh_user=root bmc_address=mgmt-f16-h11-000-1029p.rdu2.scalelab.redhat.com

[bastion:vars]
bmc_user=quads
bmc_password=XXXXXXX

[controlplane]
f16-h13-000-1029p bmc_address=mgmt-f16-h13-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:1a:d8 lab_mac=0c:c4:7a:fa:19:64 ip=198.18.10.5 vendor=Supermicro
f16-h14-000-1029p bmc_address=mgmt-f16-h14-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:1a:bc lab_mac=ac:1f:6b:c1:8a:92 ip=198.18.10.6 vendor=Supermicro
f16-h15-000-1029p bmc_address=mgmt-f16-h15-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:17:74 lab_mac=0c:c4:7a:fa:19:e2 ip=198.18.10.7 vendor=Supermicro

[controlplane:vars]
role=master
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno1
network_interface=eth0
network_prefix=24
gateway=198.18.10.1
dns1=198.18.10.1

[worker]
f16-h17-000-1029p bmc_address=mgmt-f16-h17-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:19:7c lab_mac=0c:c4:7a:fa:19:70 ip=198.18.10.8 vendor=Supermicro
f16-h18-000-1029p bmc_address=mgmt-f16-h18-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:1b:34 lab_mac=0c:c4:7a:fa:19:d4 ip=198.18.10.9 vendor=Supermicro
f16-h21-000-1029p bmc_address=mgmt-f16-h21-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:a3:14 lab_mac=0c:c4:7a:fa:a7:2a ip=198.18.10.10 vendor=Supermicro
f16-h22-000-1029p bmc_address=mgmt-f16-h22-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:19:24 lab_mac=0c:c4:7a:fa:19:4e ip=198.18.10.11 vendor=Supermicro
f16-h23-000-1029p bmc_address=mgmt-f16-h23-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:19:bc lab_mac=0c:c4:7a:fa:19:f4 ip=198.18.10.12 vendor=Supermicro
f16-h25-000-1029p bmc_address=mgmt-f16-h25-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:1b:60 lab_mac=0c:c4:7a:fa:1a:46 ip=198.18.10.13 vendor=Supermicro
f16-h27-000-1029p bmc_address=mgmt-f16-h27-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:1a:0c lab_mac=0c:c4:7a:fa:19:d0 ip=198.18.10.14 vendor=Supermicro
f16-h29-000-1029p bmc_address=mgmt-f16-h29-000-1029p.rdu2.scalelab.redhat.com network_mac=ac:1f:6b:2d:17:94 lab_mac=0c:c4:7a:fa:19:e6 ip=198.18.10.15 vendor=Supermicro

[worker:vars]
role=worker
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno1
network_interface=eth0
network_prefix=24
gateway=198.18.10.1
dns1=198.18.10.1

[remoteworker]
# Unused

[remoteworker:vars]
# Unused

[sno]
# Unused

[sno:vars]
# Unused

[hv]

[hv:vars]
ansible_user=root
ansible_ssh_pass=
bmc_user=quads
bmc_password=XXXXXXX
```

** If your bastion machine is not running RHEL 8.6, you will have to upgrade following [this short procedure](troubleshooting.md#upgrade-rhel-to-86-in-scalelab).

Next run the `setup-bastion.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
...
```

We can now set the ssh vars in the `ansible/vars/all.yml` file since `setup-bastion.yml` has completed. For bare metal clusters only `ssh_public_key_file` is required to be filled out. The recommendation is to copy the public ssh key file from your bastion local to your laptop and set `ssh_public_key_file` to the location of that file. This file determines which ssh key will be automatically permitted to ssh into the cluster's nodes.

```console
[user@fedora jetlag]$ scp root@f16-h11-000-1029p.rdu2.scalelab.redhat.com:/root/.ssh/id_rsa.pub .
Warning: Permanently added 'f16-h11-000-1029p.rdu2.scalelab.redhat.com,10.1.43.101' (ECDSA) to the list of known hosts.
id_rsa.pub                                                                                100%  554    22.6KB/s   00:00
```

Then set `ssh_public_key_file: /home/user/jetlag/id_rsa.pub` or to wherever you copied the file down to.

Finally run the `bm-deploy.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/cloud99.local ansible/bm-deploy.yml
...
```

It is suggested to monitor your first deployment to see if anything hangs on boot or if the virtual media is incorrect according to the bmc. You can monitor your deployment by opening the bastion's GUI to assisted-installer (port 8080, ex `f16-h11-000-1029p.rdu2.scalelab.redhat.com:8080`), opening the consoles via the bmc of each system, and once the machines are booted, you can directly ssh to them and tail log files.

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion.

```console
[root@f16-h11-000-1029p ~]# export KUBECONFIG=/root/bm/kubeconfig
[root@f16-h11-000-1029p ~]# oc get no
...
```
