# Deploy a Bare Metal cluster via Jetlag from a non-standard lab, BYOL (Bring Your Own Lab), quickstart

Assuming that you receive a set of machines to install OCP, this guide walks you through getting a bare-metal cluster installed on this allocation. For the purposes of the guide, the machines used are Dell r660s and r760s running RHEL 9.2. In a BYOL (or with any non-homogeneous allocation containing machines of different models) due to the non-standard interface names and NIC PCI slots, you must craft Jetlag's inventory file by hand.

In other words, the `create-inventory` playbook is not used with BYOL. You must instead create your own inventory file manually, which means gathering information regarding the machines such as NIC names and MAC addresses. Therefore, thinking about simplifying this step, it is recommended to group machines of same/similar models wisely to be the cluster's control-plane and worker nodes.

The bastion machine needs 2 interfaces:
- The interface connected to the network, i.e., with an IP assigned, a L3 network. This interface usually referred to as *lab_network* as it provides the connectivity into the bastion machine.
- The control-plane interface, from which the cluster nodes are accessed (this is a L2 network, i.e., it does not have an IP assigned).

Sometimes the bastion machine may have firewall rules in place that prevent proper connectivity from the target cluster machines to the assisted-service API hosted on the bastion. Depending on the lab setup, you might need to add rules to allow this traffic, or if the bastion machine is already behind a firewall, the firewall could be disabled. One can, for instance, check for `firewalld` or `iptables`.

The cluster machines need a minimum of 1 online private interface:
- The control-plane interface, from which other cluster nodes are accessed.

Since each node's NIC is on a L2 network, choose whichever L2 network is available as the control-plane network. See the network diagram below as an example:

![BM BYOL Cluster](img/byol_cluster.png)

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure Ansible vars in `all.yml`](#configure-ansible-vars-in-allyml)
- [Review vars all.yml](#review-vars-allyml)
- [Create your custom inventory byol.yml](#create-your-custom-inventory-byolyml)
- [Monitor install and interact with cluster](#monitor-install-and-interact-with-cluster)
- [Appendix - Troubleshooting, etc.](#appendix---troubleshooting-etc)
<!-- /TOC -->

<!-- Bastion setup is duplicated in multiple files and should be kept in sync!
     - bastion-deploy-bm-byol.md
     - bastion-bm-ibmcloud.md
     - deploy-sno-ibmcloud.md
     - deploy-sno-quickstart.md
 -->
## Bastion setup

1. Select the bastion machine from the allocation. You should run Jetlag on the
bastion machine, to ensure full connectivity and fastest access. By convention
this is usually the first node of your allocation: for example, the first machine
listed in your cloud platform's standard inventory display.

2. You can copy your ssh public key to the designated bastion machine to make it easier to
repeatedly log in from your laptop:

```console
[user@<local> ~]$ ssh-copy-id root@<bastion>
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 2 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Warning: Permanently added '<bastion>,x.x.x.x' (ECDSA) to the list of known hosts.
root@<bastion>'s password:

Number of key(s) added: 2

# Now try logging into the machine, and confirm that only the expected key(s)
# were added to ~/.ssh/known_hosts
[user@<local> ~]$ ssh root@<bastion>
[root@<bastion> ~]#
```

Now log in to the bastion (with `ssh root@<bastion>` if you copied your public key above,
or using the bastion root account password if not), because the remaining commands
should be executed from the bastion.

3. Install some additional tools to help after reboot

```console
[root@<bastion> ~]# dnf install tmux git python3-pip sshpass -y
Updating Subscription Management repositories.
...
Complete!
```

4. Setup ssh keys for the bastion root account and copy to itself to permit
local ansible interactions:

```console
[root@<bastion> ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:uA61+n0w3Dht4/oIy1IKXrSgt9tfC/8zjICd7LJ550s root@<bastion>
The key's randomart image is:
+---[RSA 3072]----+
...
+----[SHA256]-----+
[root@<bastion> ~]# ssh-copy-id root@localhost
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "/root/.ssh/id_rsa.pub"
The authenticity of host 'localhost (127.0.0.1)' can't be established.
ECDSA key fingerprint is SHA256:fvvO3NLxT9FPcoOKQ9ldVdd4aQnwuGVPwa+V1+/c4T8.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@localhost's password:

Number of key(s) added: 1

Now try logging into the machine and check to make sure that only the key(s) you wanted were added:
```console
[root@<bastion> ~]# ssh root@localhost
[root@<bastion> ~]#
```

5. Clone the `jetlag` GitHub repo

```console
[root@<bastion> ~]# git clone https://github.com/redhat-performance/jetlag.git
Cloning into 'jetlag'...
remote: Enumerating objects: 4510, done.
remote: Counting objects: 100% (4510/4510), done.
remote: Compressing objects: 100% (1531/1531), done.
remote: Total 4510 (delta 2450), reused 4384 (delta 2380), pack-reused 0
Receiving objects: 100% (4510/4510), 831.98 KiB | 21.33 MiB/s, done.
Resolving deltas: 100% (2450/2450), done.
```

The `git clone` command will normally set the local head to the Jetlag repo's
`main` branch. To set your local head to a different branch or tag (for example,
a development branch), you can add `-b <name>` to the command.

Change your working directory to the repo's `jetlag` directory, which we'll assume
for subsequent steps:

```console
[root@<bastion> ~]# cd jetlag
[root@<bastion> jetlag]#
```

6. Download your `pull_secret.txt` from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads) into the root directory of your Jetlag repo on the bastion. You'll find the Pull Secret near the end of
the long downloads page, in the section labeled "Tokens". You can either click the "Download" button, and then copy the
downloaded file to `~/jetlag/pull_secret.txt` on the bastion (notice that Jetlag expects an underscore (`_`) while the
file will download with a hyphen (`-`)); *or* click on the "Copy" button, and then paste the clipboard into the terminal
after typing `cat >pull_secret.txt` on the bastion to create the expected filename:

```console
[root@<bastion> jetlag]# cat >pull_secret.txt
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

If you are deploying nightly builds then you will need to add a ci token and an entry for
`registry.ci.openshift.org`. If you plan on deploying an ACM downstream build be sure to
include an entry for `quay.io:443`.

7. Execute the bootstrap script in the current shell, with `source bootstrap.sh`.
This will activate a local virtual Python environment configured with the Jetlag and
Ansible dependencies.

```console
[root@<bastion> jetlag]# source bootstrap.sh
Collecting pip
...
(.ansible) [root@<bastion> jetlag]#
```

You can re-enter that virtual environment when you log in to the bastion again
with:

```console
[root@<bastion> ~]# cd jetlag
[root@<bastion> jetlag]# source .ansible/bin/activate
```

<!-- End of duplicated setup text -->

## Configure Ansible vars in `all.yml`

Copy the vars file and edit it to create the inventory with your BYOL lab info:

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: byol`

Change `lab_cloud` to `lab_cloud: na`

Change `cluster_type` to `cluster_type: bm`

Set `worker_node_count` it must be correct, in this guide it is set to `2`. However, if you desire to limit the number of worker nodes. Set it to `0`, if you want a 3 node compact cluster.

Set `ocp_build` to one of 'dev' (early candidate builds) or 'ga' for Generally Available versions of OpenShift. Empty value results in playbook failing with error message. Example of dev builds would be 'candidate-4.17', 'candidate-4.16 or 'latest' (which would point to the early candidate build of the latest in development release) and examples of 'ga' builds would  be explicit versions like '4.15.20' or '4.16.0' or you could also use things like latest-4.16 to point to the latest z-stream of 4.16. Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp for a list of available builds for 'ga' releases and https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview for a list of 'dev' releases.

Set `ocp_version` to the version of the openshift-installer binary, undefined or empty results in the playbook failing with error message. Values accepted depended on the build chosen ('ga' or 'dev'). For 'ga' builds some examples of what you can use are 'latest-4.13', 'latest-4.14' or explicit versions like 4.15.2 For 'dev' builds some examples of what you can use are 'candidate-4.16' or just 'latest'.

Only change `networktype` if you need to test something other than `OVNKubernetes`

### Bastion node vars

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your Jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI).

In case of BYOL, the lab itself determines the values of `bastion_lab_interface` and `bastion_controlplane_interface`.

* `bastion_lab_interface` should be the L2 NIC interface
* `bastion_controlplane_interface` should be the L3 network NIC interface

For Dell r660 from this guide, set those vars to the following:

```yaml
bastion_lab_interface: eno8303
bastion_controlplane_interface: ens1f0
```

### OCP node vars

The system type determines the value of `controlplane_lab_interface`.

* `controlplane_lab_interface` should be the L2 NIC interface

For Dell r660 from this guide, set this var to the following:

```yaml
controlplane_lab_interface: eno8303
```

### Extra vars

No extra vars are needed for an ipv4 bare metal cluster.

Note that the `all.yml` and the `byol.local` inventory file following this section, only reflect that of an ipv4 connected install.

## Review vars `all.yml`

The `ansible/vars/all.yml` now resembles ...

```yaml
---
# Sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Which lab to be deployed into (Ex scalelab)
lab: byol
# Which cloud in the lab environment (Ex cloud42)
lab_cloud: na

# Either bm or rwn or sno
cluster_type: bm

# Applies to both bm/rwn clusters
worker_node_count: 2

# Enter whether the build should use 'dev' (early candidate builds) or 'ga' for Generally Available versions of OpenShift
# Empty value results in playbook failing with error message. Example of dev builds would be 'candidate-4.17', 'candidate-4.16'
# or 'latest' (which would point to the early candidate build of the latest in development release) and examples of 'ga' builds would
# be explicit versions like '4.15.20' or '4.16.0' or you could also use things like latest-4.16 to point to the latest z-stream of 4.16.
# Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp for a list of available builds for 'ga' releases and
# https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview for a list of 'dev' releases.
ocp_build: "ga"

# The version of the openshift-installer binary, undefined or empty results in the playbook failing with error message.
# Values accepted depended on the build chosen ('ga' or 'dev').
# For 'ga' builds some examples of what you can use are 'latest-4.13', 'latest-4.14' or explicit versions like 4.15.2
# For 'dev' builds some examples of what you can use are 'candidate-4.16' or just 'latest'
ocp_version: "latest-4.16"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

# Lab Network type, applies to sno cluster_type only
# Set this variable if you want to host your SNO cluster on lab public routable
# VLAN network, set this ONLY if you have public routable VLAN enabled in your
# scalelab cloud
public_vlan: false

# Enables FIPs security standard
enable_fips: false

ssh_private_key_file: ~/.ssh/id_rsa
ssh_public_key_file: ~/.ssh/id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned Jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull_secret.txt
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

smcipmitool_url:

bastion_lab_interface: eno8303
bastion_controlplane_interface: ens1f0

# vlaned interfaces are for remote worker node clusters only
bastion_vlaned_interface: ens1f1

# Sets up Gogs a self-hosted git service on the bastion
setup_bastion_gogs: false

# Set to enable and sync container images into a container image registry on the bastion
setup_bastion_registry: false

# Use in conjunction with ipv6 based clusters
use_bastion_registry: false

################################################################################
# OCP node vars
################################################################################
# Network configuration for all bm cluster and rwn control-plane nodes
controlplane_lab_interface: eno8303

# Network configuration for public VLAN based sno cluster_type deployment
controlplane_pub_network_cidr:
controlplane_pub_network_gateway:
jumbo_mtu: false

# Network only for remote worker nodes
# Note: these cannot be commented out or bm-deploy will fail
#       You will need to knowledge of actual interface names.
rwn_lab_interface: eno1np0
rwn_network_interface: ens1f1

################################################################################
# Extra vars
################################################################################
# Append override vars below
```

## Create your custom inventory byol.yml

Choose wisely which server for which role: bastion, masters and workers. Make sure to group machines by, e.g., number of cores, NIC types (and names), etc.

- Record the names and MACs of their L3 network NIC to be used for the inventory.
- Choose the control-plane NICs, the L2 NIC interface.
- Record the interface names and MACs of the chosen control-plane interfaces.
- The correct DNS needs to be changed in `ansible/vars/lab.yml`. Otherwise some tasks, e.g., pulling images from quay.io when Jetlag has already touched `/etc/resolv.conf`, will fail.
- Make sure you have root access to the BMC, i.e., iDRAC for Dell. In the example below, the *bmc_user* and *bmc_password* are set to root and password.

Now, create the `/ansible/inventory/byol.local` inventory file and edit it with the info from above manually from your BYOL lab:

```
# Create inventory playbook will generate this for you much easier
[all:vars]
allocation_node_count=6
supermicro_nodes=False

[bastion]
<IP or FQDN> ansible_ssh_user=root bmc_address=<IP or FQDN>

[bastion:vars]
bmc_user=root
bmc_password=password

[controlplane]
control-plane-0 bmc_address=<IP or FQDN> network_mac=<L3 NIC> lab_mac=<L2 NIC> ip=198.18.10.5 vendor=Dell install_disk=/dev/disk/by-path/...
control-plane-1 bmc_address=<IP or FQDN> network_mac=<L3 NIC> lab_mac=<L2 NIC> ip=198.18.10.6 vendor=Dell install_disk=/dev/disk/by-path/...
control-plane-2 bmc_address=<IP or FQDN> network_mac=<L3 NIC> lab_mac=<L2 NIC> ip=198.18.10.7 vendor=Dell install_disk=/dev/disk/by-path/...

[controlplane:vars]
role=master
boot_iso=discovery.iso
bmc_user=root
bmc_password=password
lab_interface=<lab_mac interface name>
network_interface=<anything>
network_prefix=24
gateway=198.18.10.1
dns1=198.18.10.1
dns2=<DNS network_mac>

[worker]
worker-0 bmc_address=172.29.170.219 network_mac=<L3 NIC> lab_mac=<L2 NIC> ip=198.18.10.8 vendor=Dell install_disk=/dev/disk/by-path/...
worker-1 bmc_address=172.29.170.73 network_mac=<L3 NIC> lab_mac=<L2 NIC> ip=198.18.10.9 vendor=Dell install_disk=/dev/disk/by-path/...

[worker:vars]
role=worker
boot_iso=discovery.iso
bmc_user=root
bmc_password=password
lab_interface=<lab_mac interface name>
network_interface=<anything>
network_prefix=24
gateway=198.18.10.1
dns1=198.18.10.1
dns2=<DNS network_mac>

[remoteworker]
[remoteworker:vars]
[sno]
[sno:vars]
[hv]
[hv:vars]
[hv_vm]
[hv_vm:vars]
```
You can see the real example file for the above inventory [here](https://github.com/redhat-performance/jetlag/blob/main/ansible/inventory/inventory-bm-byol.sample).

Next run the `setup-bastion.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/byol.local ansible/setup-bastion.yml
...
```

Finally run the `bm-deploy.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/byol.local ansible/bm-deploy.yml
...
```

## Monitor install and interact with cluster

You should monitor the first deployment to see if anything hangs on boot, or if the virtual media is incorrect according to the BMC. You can monitor the deployment by opening the bastion's `assisted-installer` GUI (port 8080, ex `http://<bastion>:8080/clusters`), opening the consoles via the BMC, i.e., iDRAC for Dell, of each machine, and once the machines are booted, you can directly connect to them and tail log files.

If everything goes well, you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion.

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/bm/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
NAME              STATUS   ROLES                  AGE   VERSION
control-plane-0   Ready    control-plane,master   36m   v1.27.6+f67aeb3
control-plane-1   Ready    control-plane,master   61m   v1.27.6+f67aeb3
control-plane-2   Ready    control-plane,master   63m   v1.27.6+f67aeb3
worker-0          Ready    worker                 38m   v1.27.6+f67aeb3
worker-1          Ready    worker                 39m   v1.27.6+f67aeb3
```

## Appendix - Troubleshooting, etc.:

There are a few peculiarities that need to be mentioned for a non-standard lab allocation and/or different versions of software, e.g., RHEL:

In Jetlag, the cluster installation process is divided into two phases: (1) Setup the bastion machine and (2) the actual OCP installation.

### (1) Setup bastion:
- Make sure that the base operating system (in the case of this guide it was RHEL 9.2) in the bastion machine has repositories added and an active subscription, since Jetlag requires some packages, such as: `dnsmasq`, `frr`, `golang-bin`, `httpd` and `httpd-tools`, `ipmitool`, `python3-pip`, `podman`, and `skopeo`.

- Sometimes the setup bastion process may fail, because it is not able to have connectivity between the assisted-service API and the target cluster machines. Check for `firewalld` or `iptables` with rules in place that prevent traffic between these machines. A quick test that fixes the problem is to silence and/or disable `firewalld` and clean `iptables` rules.

- For Jetlag to be able to copy, change the boot order, and boot the machines from the RHCOS image, the user needs to have writing access to the BMC, i.e., iDRAC in the case of Dell machines.

- The installation disks on the machines could vary from SATA/SAS to NVME, and therefore the `/dev/disk/by-path` IDs will vary.

- The task ''Stop and disable iptables'' can fail because `dnf install iptables-services` and `systemctl start` need to be done.

### (2) BM-Deploy:
- The task "Dell - Insert Virtual Media" may fail. Silencing `firewalld` and `iptables` fixed it.

- The task "Dell - Power down machine prior to booting iso" executes the `ipmi` command against the machines, where OCP will be installed. It may fail in some cases, where [reseting idrac](https://github.com/redhat-performance/jetlag/blob/main/docs/troubleshooting.md#dell---reset-bmc--idrac) is not enough. As a workaround, one can set the machines to boot from the .iso, via the virtual console.

- The task "Wait up to 40 min for nodes to be discovered" is the last most important step. Make sure that the *boot order* (via the *boot type*) is correct:
  - Check the virtual console in the BMC, i.e., iDRAC for Dell, if the machines are booting correctly from the .iso image.

  - Make sure to inspect the 'BIOS Settings' in the machine for both, the *boot order* and *boot type*. Jetlag will mount the .iso and instruct the machines for a one-time boot, where, later, they should be able to boot from the disk. Check if the string in the boot order field contains the hard disk. Once booted, in the virtual console, you will see the L3 NIC interface with an 198.10.18.x address and RHCOS, which is correct according to the `byol.local` above.
  - If the machines boot from the .iso image, but they cannot reach the bastion, it is most likely a networking issue, i.e. double check L2 and L3 NIC interfaces again.
     - [badfish](https://github.com/redhat-performance/badfish) could be used for this purpose, however, it is limited to use only FQDN, and, by the time of writing, the configuration for Del R660 and R760 in the interface config file was missing.

- In the assistant installer GUI, under cluster events, if you observe any *permission denied* error, it is related to the SELinux issue pointed out previously. If you however notice an issue related to *wrong booted device*, make sure to observe in the virtual console in the BMC, if the machines booted from the disk, and if the boot order contains the disk option. This is a classic boot order issue. The steps in the assistant installer are that the control-plane nodes will boot from the disk to be configured, and then join the control-plane "nominated" as the bootstrap node (this happens around 45-47% of the installation) to continue with the installation of the worker nodes.
