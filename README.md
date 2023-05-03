# jetlag

Tooling to install clusters for testing via an on-prem [Assisted Installer](https://github.com/openshift/assisted-installer) in the Red Hat Scale/Alias Lab and bare metal servers in IBMcloud.

Three separate layouts of clusters can be deployed:

* BM - Bare Metal - 3 control-plane nodes, X number of worker nodes
* RWN - Remote Worker Node - 3 control-plane/worker nodes, X number of remote worker nodes
* SNO - Single Node OpenShift - 1 OpenShift Master/Worker Node "cluster" per available hardware resource

Each cluster layout requires a bastion machine which is the first machine out of your lab "cloud" allocation. The bastion machine will host the assisted-installer and serve as a router for clusters with a private machine network. BM and RWN layouts produce a single cluster consisting of 3 control-plane nodes and X number of worker or remote worker nodes. SNO layout creates an SNO cluster per available machine after fulfilling the bastion machine requirement. Lastly, BM/RWN cluster types will allocate any unused machines under the `hv` ansible group which stands for hypervisor nodes. The `hv` nodes can host vms for additional clusters that can be deployed from the hub cluster. (For ACM/MCE testing)

_**Table of Contents**_

<!-- TOC -->
- [Tested Labs/Hardware](#tested-labshardware)
- [Prerequisites](#prerequisites)
- [Cluster Deployment Usage](#cluster-deployment-usage)
- [Quickstart guides](#quickstart-guides)
- [Tips and Troubleshooting](#tips-and-troubleshooting)
- [Disconnected API/Console Access](#disconnected-apiconsole-access)
- [Jetlag Hypervisors](#jetlag-hypervisors)
<!-- /TOC -->

## Tested Labs/Hardware

The listed hardware has been used for cluster deployments successfully. Potentially other hardware has been tested but just not documented here.

**Alias Lab**

| Hardware | BM  | RWN | SNO |
| -------- | --- | --- | --- |
| 740xd    | No  | No  | Yes |
| Dell r750| Yes | No  | Yes |

**Scale Lab**

| Hardware           | BM  | RWN | SNO |
| ------------------ | --- | --- | --- |
| Dell r650          | Yes | No  | Yes |
| Dell r640          | Yes | Yes | Yes |
| Dell fc640         | Yes | No  | Yes |
| Supermicro 1029p   | Yes | Yes | No  |
| Supermicro 1029U   | No  | No  | Yes |
| Supermicro 5039ms  | Yes | No  | Yes |

**IBMcloud**

| Hardware                 | BM  | SNO |
| -------------------------| --- | --- |
| Supermicro E5-2620       | Yes | Yes |
| Lenovo ThinkSystem SR630 | Yes | Yes |


## Prerequisites

Versions:

* Ansible 4.10+ (core >= 2.11.12) (on machine running jetlag playbooks)
* ibmcloud cli => 2.0.1 (IBMcloud environments)
* RHEL 8.6 / Rocky 8.6 (Bastion)
* podman 3 / 4 (Bastion)

Update to RHEL 8.7
```console
[root@xxx-xxx-xxx-r640 ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.2 (Ootpa)

[root@xxx-xxx-xxx-r640 ~]# ./update-latest-rhel-release.sh 8.7
...
[root@xxx-xxx-xxx-r640 ~]# dnf update -y
...
[root@xxx-xxx-xxx-r640 ~]# reboot
...
[root@xxx-xxx-xxx-r640 ~]# cat /etc/redhat-release
Red Hat Enterprise Linux release 8.7 (Ootpa)
```

Installing Ansible via bootstrap (requires python3-pip)

```console
[root@xxx-xxx-xxx-r640 jetlag]# source bootstrap.sh
...
(.ansible) [root@xxx-xxx-xxx-r640 jetlag]#
```

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](docs/order-hardware-ibmcloud.md) in [docs](docs) directory.

Pre-reqs for Supermicro hardware:

* [SMCIPMITool](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI) downloaded to jetlag repo, renamed to `smcipmitool.tar.gz`, and placed under `ansible/`

## Cluster Deployment Usage

There are three main files to configure and one is generated but might have to be edited for specific desired scenario/hardware usage:

* `ansible/vars/all.yml` - An ansible vars file (Sample provided `ansible/vars/all.sample.yml`)
* `pull_secret.txt` - Your OCP pull secret, download from [console.redhat.com](https://console.redhat.com/)
* `ansible/inventory/$CLOUDNAME.local` - The generated inventory file (Samples provided in `ansible/inventory`)

Start by editing the vars

```console
[root@xxx-xxx-xxx-r640 jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
[root@xxx-xxx-xxx-r640 jetlag]# vi ansible/vars/all.yml
```

Make sure to set/review the following vars:

* `lab` - either `alias` or `scalelab`
* `lab_cloud` - the cloud within the lab environment (Example: `cloud42`)
* `cluster_type` - either `bm`, `rwn`, or `sno` for the respective cluster layout
* `worker_node_count` - applies to bm and rwn cluster types for the desired worker count, ideal for leaving left over inventory hosts for other purposes
* `public_vlan` - applies to sno cluster_types, set to be `true` only for public routable vlan deployment
* `controlplane_lab_interface` - applies to bm and rwn cluster types and should map to the nodes interface in which the lab provides dhcp to and also required for public routable vlan based sno deployment(to disable this interface)
* `controlplane_pub_network_cidr` and `controlplane_pub_network_gateway` - only required for public routable vlan based sno deployment to input lab public routable vlan network and gateway
* `rwn_lab_interface` - applies only to rwn cluster type and should map to the nodes interface in which the lab provides dhcp to
* More customization like cluster_network, service_network, rwn_vlan and rwn_networks can be supported as extra vars, check default files for variable name.

Set your pull-secret in `pull_secret.txt` in repo base directory. Example:

```console
[root@xxx-xxx-xxx-r640 jetlag]# cat pull_secret.txt
{
  "auths": {
...
```

Run create-inventory playbook

```console
[root@xxx-xxx-xxx-r640 jetlag]# ansible-playbook ansible/create-inventory.yml
```

Run setup-bastion playbook

```console
[root@xxx-xxx-xxx-r640 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
```

Run deploy for either bm/rwn/sno playbook with inventory created by create-inventory playbook

Bare Metal Cluster:

```console
[root@xxx-xxx-xxx-r640 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bm-deploy.yml
```
See [troubleshooting.md](https://github.com/redhat-performance/jetlag/blob/main/docs/troubleshooting.md) in [docs](https://github.com/redhat-performance/jetlag/tree/main/docs) directory for BM install related issues

Remote Worker Node Cluster:

```console
[root@xxx-xxx-xxx-r640 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/rwn-deploy.yml
```

Single Node OpenShift:

```console
[root@xxx-xxx-xxx-r640 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/sno-deploy.yml
```

## Quickstart guides

* [Deploy a Bare Metal cluster via jetlag from a Scale Lab Bastion Machine quickstart](docs/bastion-deploy-bm.md)
* [Deploy a Bare Metal cluster on IBMcloud via jetlag quickstart](docs/deploy-bm-ibmcloud.md)
* [Deploy Single Node OpenShift (SNO) clusters via jetlag quickstart guide](docs/deploy-sno-quickstart.md)
* [Deploy Single Node OpenShift (SNO) clusters on IBMcloud via jetlag quickstart](docs/deploy-sno-ibmcloud.md)


## Tips and Troubleshooting

See [tips-and-vars.md](docs/tips-and-vars.md) in [docs](docs) directory.

See [troubleshooting.md](docs/troubleshooting.md) in [docs](docs) directory.

## Disconnected API/Console Access

See [disconnected-ipv6-cluster-access.md](docs/disconnected-ipv6-cluster-access.md) in [docs](docs) directory.

## Jetlag Hypervisors

See [hypervisors.md](docs/hypervisors.md) in [docs](docs) directory.
