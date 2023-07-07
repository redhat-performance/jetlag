# Deploy a Bare Metal cluster via jetlag from a Scale Lab Bastion Machine quickstart

Assuming you received a scale lab allocation named `cloud99`, this guide will walk you through getting a bare-metal cluster up in your allocation. For purposes of the guide the systems in `cloud99` will be Dell r650s. The recommended way to use jetlag is directly off a bastion machine. Jetlag picks the first machine in an allocation as the bastion. There are [ways to trick jetlag into picking a different machine as the bastion](tips-and-vars.md#override-lab-ocpinventory-json-file) but are beyond the scope of this quickstart.

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure vars all.yml](#configure-vars-allyml)
- [Review vars all.yml](#review-vars-allyml)
- [Run playbooks](#run-playbooks)
- [Monitor install and interact with cluster](#monitor-install-and-interact-with-cluster)
<!-- /TOC -->


## Bastion setup

1. Obtain your first machine from the allocation from the [scale lab wiki](http://wiki.rdu2.scalelab.redhat.com/)
2. Copy your ssh keys to the designated bastion machine

```console
[user@fedora ~]$ ssh-copy-id root@xxx-h01-000-r650.example.redhat.com
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 2 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Warning: Permanently added 'xxx-h01-000-r650.example.redhat.com,x.x.x.x' (ECDSA) to the list of known hosts.
root@xxx-h01-000-r650.example.redhat.com's password:

Number of key(s) added: 2

Now try logging into the machine, with:   "ssh 'root@xxx-h01-000-r650.example.redhat.com'"
and check to make sure that only the key(s) you wanted were added.
[user@fedora ~]$
```

3. Update the version of RHEL that came on the bastion machine and reboot

```console
[user@fedora ~]$ ssh root@xxx-h01-000-r650.example.redhat.com
...
[root@xxx-h01-000-r650 ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.2 (Ootpa)

[root@xxx-h01-000-r650 ~]# ./update-latest-rhel-release.sh 8.7
Changing repository from 8.2 to 8.7
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 8.7

[root@xxx-h01-000-r650 ~]# dnf update -y
Updating Subscription Management repositories.
Unable to read consumer identity
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
rhel87 AppStream                                                                                                                                              245 MB/s | 7.8 MB     00:00    
rhel87 BaseOS                                                                                                                                                 119 MB/s | 2.4 MB     00:00    
Extra Packages for Enterprise Linux 8 - x86_64                                                                                                                 14 MB/s |  14 MB     00:00    
Last metadata expiration check: 0:00:01 ago on Tue 02 May 2023 06:58:15 PM UTC.
Dependencies resolved.
...
Complete!
[root@xxx-h01-000-r650 ~]# reboot
Connection to xxx-h01-000-r650.rdu2.scalelab.redhat.com closed by remote host.
Connection to xxx-h01-000-r650.rdu2.scalelab.redhat.com closed.
...
[user@fedora ~]$ ssh root@xxx-h01-000-r650.example.redhat.com
...
[root@xxx-h01-000-r650 ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.7 (Ootpa)
```

4. Install some additional tools to help after reboot

```console
[root@xxx-h01-000-r650 ~]# dnf install tmux git python3-pip sshpass -y
Updating Subscription Management repositories.
...
Complete!
```

5. Setup ssh keys on the bastion and copy to itself to permit local ansible interactions

```console
[root@xxx-h01-000-r650 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:uA61+n0w3Dht4/oIy1IKXrSgt9tfC/8zjICd7LJ550s root@xxx-h01-000-r650.rdu2.scalelab.redhat.com
The key's randomart image is:
+---[RSA 3072]----+
...
+----[SHA256]-----+
[root@xxx-h01-000-r650 ~]# ssh-copy-id root@localhost
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:fvvO3NLxT9FPcoOKQ9ldVdd4aQnwuGVPwa+V1+/c4T8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@localhost's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@localhost'"
and check to make sure that only the key(s) you wanted were added.
[root@xxx-h01-000-r650 ~]#
```

6. Clone jetlag

```console
[root@xxx-h01-000-r650 ~]# git clone https://github.com/redhat-performance/jetlag.git
Cloning into 'jetlag'...
remote: Enumerating objects: 4510, done.
remote: Counting objects: 100% (4510/4510), done.
remote: Compressing objects: 100% (1531/1531), done.
remote: Total 4510 (delta 2450), reused 4384 (delta 2380), pack-reused 0
Receiving objects: 100% (4510/4510), 831.98 KiB | 21.33 MiB/s, done.
Resolving deltas: 100% (2450/2450), done.
```

7. Download your pull_secret.txt from [console.redhat.com](https://console.redhat.com/) and place it in the root directory of jetlag

```console
[root@xxx-h01-000-r650 jetlag]# cat pull_secret.txt
{
  "auths": {
...
```

8. Change to jetlag directory, source bootstrap.sh

```console
[root@xxx-h01-000-r650 ~]# cd jetlag/
[root@xxx-h01-000-r650 jetlag]# source bootstrap.sh
Collecting pip
...
(.ansible) [root@xxx-h01-000-r650 jetlag]#
```


## Configure vars all.yml

Copy the vars file and edit it

```console
(.ansible) [root@xxx-h01-000-r650 jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@xxx-h01-000-r650 jetlag]# vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: scalelab`

Change `lab_cloud` to `lab_cloud: cloud99`

Change `cluster_type` to `cluster_type: bm`

Set `worker_node_count` if you desire to limit the number of worker nodes from your scale lab allocation. Set it to `0` if you want a 3 node compact cluster.

Change `ocp_release_image` to the desired image if the default (4.12.16) is not the desired version.
If you change `ocp_release_image` to a different major version (Ex `4.12`), then change `openshift_version` accordingly.

Only change `networktype` if you need to test something other than `OVNKubernetes`

### Bastion node vars

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI).

The system type determines the values of `bastion_lab_interface` and `bastion_controlplane_interface`.

Using the chart provided by the [scale lab here](http://docs.scalelab.redhat.com/trac/scalelab/wiki/ScaleLabTipsAndTricks#RDU2ScaleLabPrivateNetworksandInterfaces), determine the names of the nic per network for EL8.

* `bastion_lab_interface` will always be set to the nic name under "Public Network"
* `bastion_controlplane_interface` should be set to the nic name under "Network 1" for this guide

For Dell r650 set those vars to the following

```yaml
bastion_lab_interface: eno12399np0
bastion_controlplane_interface: ens1f0
```

Here you can see a network diagram for the bare metal cluster on Dell r650 with 3 workers and 3 master nodes:

![BM Cluster](img/bm_cluster.png)

Double check your nic names with your actual bastion machine.

** If you desire to use a *different network* than "Network 1" for your controlplane network then you will have to append some additional overrides to the extra vars portion of the all.yml vars file.
See [tips and vars](https://github.com/redhat-performance/jetlag/blob/main/docs/tips-and-vars.md#Other-Networks) for more information

### OCP node vars

The same chart provided by the scale lab for the bastion machine, is used to identify the nic names for `controlplane_lab_interface`.

* `controlplane_lab_interface` should always be set to the nic name under "Public Network" for the specific system type

For Dell r650 set `controlplane_lab_interface` var to the following

```yaml
controlplane_lab_interface: eno12399np0
```

** If your machine types are not homogeneous, then you will have to manually edit your generated inventory file to correct any nic names until this is reasonably automated.

### Extra vars

No extra vars are needed for an ipv4 bare metal cluster.

### Disconnected and ipv6 vars

If you want to deploy a disconnected ipv6 cluster then the following vars need to be set.

Change `setup_bastion_registry` to `setup_bastion_registry: true` and `use_disconnected_registry` to `use_disconnected_registry: true` under "Bastion node vars"

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

## Review vars all.yml

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
worker_node_count: 0

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
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.12.16-x86_64

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

smcipmitool_url:

bastion_lab_interface: eno12399np0
bastion_controlplane_interface: ens1f0

# vlaned interfaces are for remote worker node clusters only
bastion_vlaned_interface: ens1f1

# Sets up Gogs a self-hosted git service on the bastion
setup_bastion_gogs: false

# Set to enable and sync container images into a container image registry on the bastion
setup_bastion_registry: false

# Use in conjunction with ipv6 based clusters
use_disconnected_registry: false

################################################################################
# OCP node vars
################################################################################
# Network configuration for all bm cluster and rwn control-plane nodes
controlplane_lab_interface: eno12399np0

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
(.ansible) [root@xxx-h01-000-r650 jetlag]# ansible-playbook ansible/create-inventory.yml
...
```

The `create-inventory.yml` playbook will create an inventory file `ansible/inventory/cloud99.local` from the lab allocation data and the vars file.

The inventory file resembles ...

```
[all:vars]
allocation_node_count=16
supermicro_nodes=False

[bastion]
xxx-h01-000-r650.rdu2.scalelab.redhat.com ansible_ssh_user=root bmc_address=mgmt-xxx-h01-000-r650.rdu2.scalelab.redhat.com

[bastion:vars]
bmc_user=quads
bmc_password=XXXXXXX

[controlplane]
xxx-h02-000-r650 bmc_address=mgmt-xxx-h02-000-r650.rdu2.scalelab.redhat.com network_mac=b4:96:91:cb:ec:02 lab_mac=5c:6f:69:75:c0:70 ip=198.18.10.5 vendor=Dell install_disk=/dev/sda
xxx-h03-000-r650 bmc_address=mgmt-xxx-h03-000-r650.rdu2.scalelab.redhat.com network_mac=b4:96:91:cc:e5:80 lab_mac=5c:6f:69:56:dd:c0 ip=198.18.10.6 vendor=Dell install_disk=/dev/sda
xxx-h05-000-r650 bmc_address=mgmt-xxx-h05-000-r650.rdu2.scalelab.redhat.com network_mac=b4:96:91:cc:e6:40 lab_mac=5c:6f:69:56:b0:50 ip=198.18.10.7 vendor=Dell install_disk=/dev/sda

[controlplane:vars]
role=master
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno12399np0
network_interface=eth0
network_prefix=24
gateway=198.18.10.1
dns1=198.18.10.1

[worker]

[worker:vars]
role=worker
boot_iso=discovery.iso
bmc_user=quads
bmc_password=XXXXXXX
lab_interface=eno12399np0
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
(.ansible) [root@xxx-h01-000-r650 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
...
```

Finally run the `bm-deploy.yml` playbook ...

```console
(.ansible) [root@xxx-h01-000-r650 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bm-deploy.yml
...
```

## Monitor install and interact with cluster

It is suggested to monitor your first deployment to see if anything hangs on boot or if the virtual media is incorrect according to the bmc. You can monitor your deployment by opening the bastion's GUI to assisted-installer (port 8080, ex `xxx-h01-000-r650.rdu2.scalelab.redhat.com:8080`), opening the consoles via the bmc of each system, and once the machines are booted, you can directly ssh to them and tail log files.

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion.

```console
[root@xxx-h01-000-r650 ~]# export KUBECONFIG=/root/bm/kubeconfig
[root@xxx-h01-000-r650 ~]# oc get no
NAME               STATUS   ROLES                         AGE    VERSION
xxx-h02-000-r650   Ready    control-plane,master,worker   73m    v1.25.7+eab9cc9
xxx-h03-000-r650   Ready    control-plane,master,worker   103m   v1.25.7+eab9cc9
xxx-h05-000-r650   Ready    control-plane,master,worker   105m   v1.25.7+eab9cc9
```
