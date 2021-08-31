# Deploy Single Node OpenShift clusters on IBMcloud via jetlag quickstart

To deploy Single Node OpenShift (SNO) clusters on IBMcloud hardware you can simply follow the bare metal cluster guide with a few differences. The changes in this guide will apply after [Review ibmcloud.yml](deploy-bm-ibmcloud.md#review-ibmcloudyml) section.

## SNO var changes

Change `cluster_type` to `cluster_type: sno`

Change `sno_node_count` to the number of SNOs that should be provisioned. For Example `sno_node_count: 2`

Change `private_network_cidr` to the network cidr for the private network of your hardware. For Example `private_network_cidr: X.X.X.0/26`

Clear out settings for `controlplane_network_api` and `controlplane_network_ingress`

## Review SNO ibmcloud.yml

The `ansible/vars/ibmcloud.yml` now resembles ..

```yaml
---
# ibmcloud sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Lab is ibmcloud in this case
lab: ibmcloud

cluster_type: sno

hardware_vendor: Supermicro

# Applies to bm clusters
worker_node_count:

# Applies to sno clusters
sno_node_count: 2

# Versions are controlled by this release image. If you want to change images
# you must stop and rm all assisted-installer containers on the bastion and rerun
# the setup-bastion step in order to setup your bastion's assisted-installer to
# the version you specified
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.8.9-x86_64

# This should just match the above release image version (Ex: 4.8)
openshift_version: "4.8"

# List type: Use only one of OpenShiftSDN or OVNKubernetes for BM/RWN, but could be both for SNO mix and match
networktype:
  - OVNKubernetes

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

bastion_public_interface: bond1

bastion_private_interfaces:
- bond0
- int0
- int1

dns_servers:
- X.X.X.X
- Y.Y.Y.Y

base_dns_name: performance-scale.cloud

################################################################################
# OCP node vars
################################################################################
# Network configuration for cluster control-plane nodes
private_bond_interfaces:
- enp1s0f0
- enp2s0f0

# Applies to sno only and serves as machine network
private_network_cidr: X.X.X.0/26

private_network_prefix: 26

cluster_name: jetlag-ibm

controlplane_network_api:
controlplane_network_ingress:

################################################################################
# Extra vars
################################################################################
# Append override vars below
```

## Run playbooks

Run the ibmcloud create inventory playbook

```console
[user@fedora jetlag]$ ansible-playbook ansible/ibmcloud-create-inventory.yml
...
```

The `ibmcloud-create-inventory.yml` playbook will create an inventory file `ansible/inventory/ibmcloud.local` from the ibmcloud cli data and the vars file.

The inventory file should resemble the [sample one provided](../ansible/inventory/ibmcloud-inventory-sno.sample).

Next run the `ibmcloud-setup-bastion.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml
...
```

Prior to running the deploy playbook, you will need to connect to ibmcloud using vpn and should be able to directly open each node's bmc web gui. Use the credentials in the inventory file per host's bmc in order to login. It is best to open each console so you can observe when a node reboots. Also set each screen to the Virtual Media CD-ROM Image page. You can pre-set the image for Supermicro machine to match:

Share Host - `http://X.X.X.X:8081`

Path to Image - `\\$HOSTNAME.iso`

**The two slashes (`\\`) are required and is not a typo.**

Replace `$HOSTNAME` with the entry of the SNO in the inventory. For Example `\\jetlag-bm4.iso`

Finally run the `ibmcloud-sno-deploy.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-sno-deploy.yml
...
```

While the playbook is running, it will prompt that you mounted the Virtual Media per SNO:

```console
TASK [ibmcloud-sno-generate-discovery-iso : Pause to allow manual discovery iso mounting for ibmcloud] ***************************************************************************************
Monday 09 August 2021  15:07:01 -0400 (0:00:02.764)       0:00:42.555 *********
[ibmcloud-sno-generate-discovery-iso : Pause to allow manual discovery iso mounting for ibmcloud]
Confirm each machine's BMC's virtualmedia mounts http://X.X.X.X:8081/jetlag-bm4.iso:
^Mok: [jetlag-bm0] => (item=jetlag-bm4)
[ibmcloud-sno-generate-discovery-iso : Pause to allow manual discovery iso mounting for ibmcloud]
Confirm each machine's BMC's virtualmedia mounts http://X.X.X.X:8081/jetlag-bm5.iso:
ok: [jetlag-bm0] => (item=jetlag-bm5)
```

Confirm that the Virtual Media is mounted according to each machine's BMC. It then reminds you with another prompt to observe the consoles and unmount the virtual media **after** machines reboot:

```console
TASK [ibmcloud-sno-generate-discovery-iso : Remind to watch for when to unmount the virtual ISO media] ***************************************************************************************
Monday 09 August 2021  15:08:59 -0400 (0:00:04.208)       0:02:40.744 *********
[ibmcloud-sno-generate-discovery-iso : Remind to watch for when to unmount the virtual ISO media]
Remember to watch the consoles and unmount immediate after a machine reboots:
ok: [jetlag-bm0]
```

Since each cluster is an SNO, each node will reboot in approximately 10 minutes, you must observe the consoles to see when the reboot occurs. Once the reboot occurs, you can switch to the BMC web gui and unmount the discovery iso cd. If you fail to watch the consoles closely and miss the reboot to unmount the ISO at the correct time, the cluster will fail to complete install as the machines will always boot into the discovery ISO. You will be able to see this status if you also observe the Assisted-installer GUI on the bastion machine. (http://$BASTION_IP:8080) You can also ssh to each node while it is running the discovery image from your bastion machine and tail journal logs to see status of the disk writing and reboot process.

If everything goes well you should have SNO(s) in about 40-60 minutes. You can interact with the SNOs from the bastion.

```console
[root@jetlag-bm0 ~]# cd sno/
[root@jetlag-bm0 sno]# oc --kubeconfig=jetlag-bm5/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm5   Ready    master,worker   48m   v1.21.1+051ac4f
[root@jetlag-bm0 sno]# oc --kubeconfig=jetlag-bm4/kubeconfig get no
NAME         STATUS   ROLES           AGE   VERSION
jetlag-bm4   Ready    master,worker   48m   v1.21.1+051ac4f

```

You can also copy the kubeconfig to your local machine and interact with it if you are on the ibmcloud vpn, and add the appropriate `/etc/hosts` entries to your local `/etc/hosts` file.
