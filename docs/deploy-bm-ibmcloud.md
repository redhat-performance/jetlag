# Deploy a Bare Metal cluster on IBMcloud via jetlag quickstart

To deploy a bare metal OpenShift cluster, order 6 machines from the [IBM bare metal server catalog](https://cloud.ibm.com/gen1/infrastructure/provision/bm).
For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](../docs/order-hardware-ibmcloud.md) in [docs](../docs) directory.
The machines used to test this are of Server profile E5-2620 in DAL10 datacenter with automatic port redundancy. One machine will become the bastion, 3 machines will become control-plane nodes, and the remaining 2 nodes will be worker nodes. Ensure that you order either CentOS or RHEL machines with a new enough version (8.6) otherwise podman will not have host networking functionality. The bastion machine should have a public accessible ip and will NAT traffic for the cluster to the public network. The other machines can have a public ip address but it is not currently in use with this deployment method.

Once your machines are delivered, login to the ibmcloud cli using the cut and paste link from the cloud portal. You should be able to list the machines from your local machine, for example:

```console
$ ibmcloud sl hardware list
id        hostname     domain                    public_ip        private_ip    datacenter   status   
960237    jetlag-bm0   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE   
1165601   jetlag-bm1   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE   
1112925   jetlag-bm2   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE   
1163781   jetlag-bm3   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE   
1165519   jetlag-bm4   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE   
1117051   jetlag-bm5   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE  
```

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

## ibmcloud.yml vars file

Next copy the vars file so we can edit it.

```console
[user@fedora jetlag]$ cp ansible/vars/ibmcloud.sample.yml ansible/vars/ibmcloud.yml
[user@fedora jetlag]$ vi ansible/vars/ibmcloud.yml
```

### Lab & cluster infrastructure vars

Change `lab` to `lab: ibmcloud`

Change `cluster_type` to `cluster_type: bm`

Set `worker_node_count` if you need to limit the number of worker nodes from available hardware.

Change `ocp_release_image` to the required image if the default (4.13.17) is not the desired version.
If you change `ocp_release_image` to a different major version (Ex `4.13`), then change `openshift_version` accordingly.

Only change `networktype` if you need to test something other than `OVNKubernetes`

Set `ssh_private_key_file` and `ssh_public_key_file` to the file location of the ssh key files to access your ibmcloud bare metal servers.

### Bastion node vars

The bastion node is usually the first node in the hardware list. In our testbed's case, `bond0` is the private network, and `bond1` is the public network. This matches the defaults for `bastion_public_interface` and `bastion_private_interfaces`. It is unknown if this changes in other hardware or datacenters.

Next, identify your dns servers for your hardware by sshing to the expected bastion machine and reading `/etc/resolv.conf` on the machine. Supply those dns servers to the `dns_servers` list.

```yaml
dns_servers:
- X.X.X.X
- Y.Y.Y.Y
```

Set `base_dns_name` to the expected base dns name, for example `base_dns_name: performance-scale.cloud`

Set `smcipmitool_url` to the location of the Supermicro SMCIPMITool binary. Since you must accept a EULA in order to download, it is suggested to download the file and place it onto a local http server, that is accessible to your laptop or deployment machine. You can then always reference that URL. Alternatively, you can download it to the `ansible/` directory of your jetlag repo clone and rename the file to `smcipmitool.tar.gz`. You can find the file [here](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI).

### OCP node vars

For the OCP nodes it might be necessary to adjust the `private_network_prefix`.  Check your hardware's subnet to determine the prefix.

While inspecting the subnet at cloud.ibm.com, determine two free addresses in the subnet to be used as api and ingress addresses. Provide those addresses in `controlplane_network_api` and `controlplane_network_ingress` as required.

### Extra vars

For the purposes of this guide no extra vars are required.

## Review ibmcloud.yml

The `ansible/vars/ibmcloud.yml` now resembles ..

```yaml
---
# ibmcloud sample vars file
################################################################################
# Lab & cluster infrastructure vars
################################################################################
# Lab is ibmcloud in this case
lab: ibmcloud

cluster_type: bm

# Applies to bm clusters
worker_node_count: 2

# Applies to sno clusters
sno_node_count:

# Versions are controlled by this release image. If you want to change images
# you must stop and rm all assisted-installer containers on the bastion and rerun
# the setup-bastion step in order to setup your bastion's assisted-installer to
# the version you specified
ocp_release_image: quay.io/openshift-release-dev/ocp-release:4.13.17-x86_64

# This should just match the above release image version (Ex: 4.13)
openshift_version: "4.13"

# Either "OVNKubernetes" or "OpenShiftSDN" (Only for BM/RWN cluster types)
networktype: OVNKubernetes

ssh_private_key_file: ~/.ssh/ibmcloud_id_rsa
ssh_public_key_file: ~/.ssh/ibmcloud_id_rsa.pub
# Place your pull_secret.txt in the base directory of the cloned jetlag repo, Example:
# [user@fedora jetlag]$ ls pull_secret.txt
pull_secret: "{{ lookup('file', '../pull_secret.txt') }}"

################################################################################
# Bastion node vars
################################################################################
bastion_cluster_config_dir: /root/{{ cluster_type }}

bastion_public_interface: bond1

bastion_private_interfaces:
- bond0
- int0
- int2

dns_servers:
- X.X.X.X
- Y.Y.Y.Y

base_dns_name: performance-scale.cloud

smcipmitool_url: http://example.lab.com/tools/SMCIPMITool_2.25.0_build.210326_bundleJRE_Linux_x64.tar.gz

################################################################################
# OCP node vars
################################################################################
# Network configuration for cluster control-plane nodes

# Applies to sno only and serves as machine network
private_network_cidr:

private_network_prefix: 26

cluster_name: jetlag-ibm

controlplane_network_api: X.X.X.3
controlplane_network_ingress: X.X.X.4

################################################################################
# Extra vars
################################################################################
# Append override vars below
# Optional: Add IBM hardware id  [$ ibmcloud sl hardware list]
bastion_hardware_id: bs_id

controlplane_hardware_ids:
- node1_id
- node2_id
- node3_id
```

## Run playbooks

### Prerequisite

1. Bastion: update public key in authorized_keys
```
$ ssh-keygen
$ cd .ssh
$ echo id_rsa.pub >> authorized_keys
```

2. Open IBM cloud case 'Set Privilege Level to ADMINISTRATOR for IPMI' for all machines.

Run the ibmcloud create inventory playbook

```console
[user@fedora jetlag]$ ansible-playbook ansible/ibmcloud-create-inventory.yml
...
```

The `ibmcloud-create-inventory.yml` playbook will create an inventory file `ansible/inventory/ibmcloud.local` from the ibmcloud cli data and the vars file.

** For custom master/worker node name: replace first parameter in ibmcloud.local file under [controlplane] and [worker] sections   

The inventory file should resemble the [sample one provided](../ansible/inventory/ibmcloud-inventory-bm.sample).

Next run the `ibmcloud-setup-bastion.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml
...
```

Lastly, run the `ibmcloud-bm-deploy.yml` playbook ...

```console
[user@fedora jetlag]$ ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-bm-deploy.yml
...
```

If everything goes well you should have a cluster in about 60-70 minutes. You can interact with the cluster from the bastion.

```console
[root@jetlag-bm0 ~]# export KUBECONFIG=/root/bm/kubeconfig
[root@jetlag-bm0 ~]# oc get no
NAME         STATUS   ROLES    AGE     VERSION
jetlag-bm1   Ready    master   3h34m   v1.21.1+051ac4f
jetlag-bm2   Ready    master   3h7m    v1.21.1+051ac4f
jetlag-bm3   Ready    master   3h34m   v1.21.1+051ac4f
jetlag-bm4   Ready    worker   3h12m   v1.21.1+051ac4f
jetlag-bm5   Ready    worker   3h13m   v1.21.1+051ac4f
```

You can also copy the kubeconfig to your local machine and interact with it if you are on the ibmcloud vpn, and add the appropriate `/etc/hosts` entries to your local `/etc/hosts` file.
