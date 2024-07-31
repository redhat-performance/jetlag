# Deploy a Single Node OpenShift cluster via Jetlag quickstart

Assuming you received a scale lab allocation named `cloud99`, this guide will walk you through getting a Single Node OpenShift (SNO) cluster up in your allocation. For purposes of the guide the systems in `cloud99` will be Supermicro 1029U. You should run Jetlag directly on the bastion machine. Jetlag picks the first machine in an allocation as the bastion. You can [trick Jetlag into picking a different machine as the bastion](tips-and-vars.md#override-lab-ocpinventory-json-file) but that is beyond the scope of this quickstart. You can find the machines in your cloud allocation on
[the scale lab wiki](http://wiki.rdu3.lab.perfscale.redhat.com/)

_**Table of Contents**_

<!-- TOC -->
- [Bastion setup](#bastion-setup)
- [Configure Ansible vars in `all.yml`](#configure-ansible-vars-in-allyml)
- [Review all.yml](#review-allyml)
- [Run playbooks](#run-playbooks)
<!-- /TOC -->

<!-- Bastion setup is duplicated in multiple files and should be kept in sync!
     - deploy-bm-alias.md
     - deploy-bm-byol.md
     - deploy-bm-ibmcloud.md
     - deploy-bm-scale.md
     - deploy-sno-alias.md
     - deploy-sno-ibmcloud.md
     - deploy-sno-scale.md
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

3. Upgrade RHEL to at least RHEL 8.6

You need to be running at least RHEL 8.6 to have the minimal `podman`. By default,
the SCALE lab installs RHEL 8.2. We recommend upgrading to RHEL 8.9
using the `/root/update-latest-rhel-release.sh` script provisioned by the QUADS
system. You can determine the installed version by looking at `/etc/redhat-release`,
and the update script allows you to ask what versions are available:

```console
[root@<bastion> ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.2 (Ootpa)
[root@<bastion> ~]# /root/update-latest-rhel-release.sh list`
8.2 8.6 8.9
```

```console
[root@<bastion> ~]# ./update-latest-rhel-release.sh 8.9
Changing repository from 8.2 to 8.9
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 8.9

[root@<bastion> ~]# dnf update -y
Updating Subscription Management repositories.
Unable to read consumer identity
This system is not registered to Red Hat Subscription Management. You can use subscription-manager to register.
rhel89 AppStream                                                                                                                                              245 MB/s | 7.8 MB     00:00
rhel89 BaseOS                                                                                                                                                 119 MB/s | 2.4 MB     00:00
Extra Packages for Enterprise Linux 8 - x86_64                                                                                                                 14 MB/s |  14 MB     00:00
Last metadata expiration check: 0:00:01 ago on Tue 02 May 2023 06:58:15 PM UTC.
Dependencies resolved.
...
Complete!
[root@<bastion> ~]# reboot
Connection to <bastion> closed by remote host.
Connection to <bastion> closed.
...
[user@<local> ~]$ ssh root@<bastion>
...
[root@<bastion> ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.9 (Ootpa)
```

4. Install some additional tools to help after reboot

```console
[root@<bastion> ~]# dnf install tmux git python3-pip sshpass -y
Updating Subscription Management repositories.
...
Complete!
```

5. Setup ssh keys for the bastion root account and copy to itself to permit
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
```

Now log in to the bastion (with `ssh root@<bastion>` if you copied your public key above,
or using the bastion root account password if not), because the remaining commands
should be executed from the bastion.

6. Clone the `jetlag` GitHub repo

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

7. Download your `pull_secret.txt` from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads) into the root directory of your Jetlag repo on the bastion. You'll find the Pull Secret near the end of
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

8. Execute the bootstrap script in the current shell, with `source bootstrap.sh`.
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

Next copy the vars file so we can edit it.

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/all.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: alias`

Change `lab_cloud` to `lab_cloud: cloud99`

Change `cluster_type` to `cluster_type: sno`

Set `ocp_build` to one of 'dev' (early candidate builds) or 'ga' for Generally Available versions of OpenShift. Empty value results in playbook failing with error message. Example of dev builds would be 'candidate-4.17', 'candidate-4.16 or 'latest' (which would point to the early candidate build of the latest in development release) and examples of 'ga' builds would  be explicit versions like '4.15.20' or '4.16.0' or you could also use things like latest-4.16 to point to the latest z-stream of 4.16. Checkout https://mirror.openshift.com/pub/openshift-v4/clients/ocp for a list of available builds for 'ga' releases and https://mirror.openshift.com/pub/openshift-v4/clients/ocp-dev-preview for a list of 'dev' releases.

Set `ocp_version` to the version of the openshift-installer binary, undefined or empty results in the playbook failing with error message. Values accepted depended on the build chosen ('ga' or 'dev'). For 'ga' builds some examples of what you can use are 'latest-4.13', 'latest-4.14' or explicit versions like 4.15.2 For 'dev' builds some examples of what you can use are 'candidate-4.16' or just 'latest'.

For the ssh keys we have a chicken before the egg problem in that our bastion machine won't be defined or ensure that keys are created until after we run `create-inventory.yml` and `setup-bastion.yml` playbooks. We will revisit that a little bit later.

### Bastion node vars

By default, Jetlag will choose the first node in an allocation as the bastion node.

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your Jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI).

The system type determines the values of `bastion_lab_interface` and `bastion_controlplane_interface`.

Using the chart provided by the [alias lab here](https://wiki.rdu3.labs.perfscale.redhat.com/usage/#Private_Networking), determine the names of the nic per network for EL8.

* `bastion_lab_interface` will always be set to the nic name under "Public Network"
* `bastion_controlplane_interface` should be set to the nic name under "EM1" for this guide

You may have to ssh to your intended bastion machine and view the network interface names to ensure the correct nic name is picked here.

Here you can see a network diagram for the SNO cluster on Dell r750 with 3 SNO clusters:

![SNO Cluster](img/sno_cluster.png)

For example if your bastion is ...

Dell r750
```yaml
bastion_lab_interface: eno8303
bastion_controlplane_interface: ens3f0
```

Dell r740xd
```yaml
bastion_lab_interface: eno3
bastion_controlplane_interface: eno1
```

Dell r7425
```yaml
bastion_lab_interface: eno3
bastion_controlplane_interface: eno1
```

For the guide we set our values for the Dell r750.

** If you desire to use a different network than "Network 1" for your controlplane network then you will have to append some additional overrides to the extra vars portion of the all.yml vars file.

### OCP node vars

The same chart provided by the alias lab for the bastion machine, is used to identify the nic names for `controlplane_lab_interface`.

* `controlplane_lab_interface` should always be set to the nic name under "Public Network" for the specific system type

For example if your Bare Metal OpenShift systems are ...

Dell r750 (on ALIAS lab)
```yaml
controlplane_lab_interface: eno8303
```

For the guide we set our values for the Dell r750.
** If your machine types are not homogeneous, then you will have to manually edit your generated inventory file to correct any nic names until this is reasonably automated.

### Extra vars

No extra vars are needed for an IPv4 SNO cluster.

### Disconnected and ipv6 vars

If you want to deploy a disconnected IPv6 cluster then the following vars need to be set.

Change `setup_bastion_registry` to `setup_bastion_registry: true` and `use_bastion_registry` to `use_bastion_registry: true` under "Bastion node vars"

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

## Review `all.yml`

The `ansible/vars/all.yml` now resembles ..

```yaml
---
# Sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Which lab to be deployed into (Ex alias)
lab: alias
# Which cloud in the lab environment (Ex cloud42)
lab_cloud: cloud99

# Either bm or rwn or sno
cluster_type: sno

# Applies to both bm/rwn clusters
worker_node_count:

# Lab Network type, applies to sno cluster_type only
# Set this variable if you want to host your SNO cluster on lab public routable
# VLAN network, set this ONLY if you have public routable VLAN enabled in your
# scalelab cloud
public_vlan: false

# The version of the openshift-installer, undefined or empty results in the playbook failing with error message.
# Values accepted: 'latest-4.13', 'latest-4.14', explicit version i.e. 4.15.2 or for dev builds, candidate-4.16
ocp_version: "latest-4.15"

# Enter whether the build should use 'dev' (nightly builds) or 'ga' for Generally Available version of OpenShift
# Empty value results in playbook failing with error message.
ocp_build: "ga"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

ssh_private_key_file: ~/.ssh/id_rsa
ssh_public_key_file: ~/.ssh/id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned Jetlag repo, Example:
# [root@<bastion> jetlag]# ls pull_secret.txt
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

smcipmitool_url: http://example.lab.com/tools/SMCIPMITool_2.25.0_build.210326_bundleJRE_Linux_x64.tar.gz

bastion_lab_interface: eno8303
bastion_controlplane_interface: ens3f0

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
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
...
```

The `create-inventory.yml` playbook will create an inventory file `ansible/inventory/cloud99.local` from the lab allocation data and the vars file.

The inventory file resembles ...

```
[all:vars]
allocation_node_count=6
supermicro_nodes=True

[bastion]
f12-h05-000-1029u.rdu3.lab.perfscale.redhat.com ansible_ssh_user=root bmc_address=mgmt-f12-h05-000-1029u.rdu3.lab.perfscale.redhat.com

[bastion:vars]
bmc_user=quads
bmc_password=xxxx

[controlplane]
# Unused

[controlplane:vars]
# Unused

[worker]
# Unused

[worker:vars]
# Unused

[remoteworker]
# Unused

[remoteworker:vars]
# Unused

[sno]
# Single Node OpenShift Clusters
f12-h06-000-1029u bmc_address=mgmt-f12-h06-000-1029u.rdu3.lab.perfscale.redhat.com boot_iso=f12-h06-000-1029u.iso ip_address=10.1.38.222 vendor=Supermicro lab_mac=ac:1f:6b:56:57:0e network_mac=00:25:90:5f:5f:5b

[sno:vars]
bmc_user=quads
bmc_password=xxxx
dns1=10.1.36.1
dns2=10.1.36.2

[hv]
# Unused

[hv:vars]
# Unused

[hv_vm]
# Unused

[hv_vm:vars]
# Unused
```

** If your bastion machine is not running RHEL 8.6 or newer, you will have to upgrade following [this short procedure](troubleshooting.md#scalelab---upgrade-rhel).

Next run the `setup-bastion.yml` playbook ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
...
```

We can now set the ssh vars in the `ansible/vars/all.yml` file since `setup-bastion.yml` has completed. For bare metal clusters only `ssh_public_key_file` is required to be filled out. The recommendation is to copy the public ssh key file from your bastion local to your laptop and set `ssh_public_key_file` to the location of that file. This file determines which ssh key will be automatically permitted to ssh into the cluster's nodes.

```console
[user@<local> ~]$ scp root@<bastion>:/root/.ssh/id_rsa.pub .
Warning: Permanently added '<bastion>,10.1.43.101' (ECDSA) to the list of known hosts.
id_rsa.pub                                                                                100%  554    22.6KB/s   00:00
```

Then set `ssh_public_key_file: /home/user/jetlag/id_rsa.pub` or to wherever you copied the file down to.

Finally run the `sno-deploy.yml` playbook from the bastion ...

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/sno-deploy.yml
...
```

A typical deployment will require around 60-70 minutes to complete mostly depending upon how fast your systems reboot. It is suggested to monitor your first deployment to see if anything hangs on boot or if the virtual media is incorrect according to the bmc. You can monitor your deployment by opening the bastion's GUI to assisted-installer (port 8080, ex `f12-h05-000-1029u.rdu3.lab.perfscale.redhat.com:8080`), opening the consoles via the bmc of each system, and once the machines are booted, you can directly ssh to them and tail log files.

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion. Look for the kubeconfig file under `/root/sno/...`

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/sno/<SNO's hostname>/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
...
```
