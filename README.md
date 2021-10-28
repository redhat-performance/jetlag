# jetlag

Tooling to install clusters for testing via an on-prem [Assisted Installer](https://github.com/openshift/assisted-installer) in the Red Hat Scale/Alias Lab and bare metal servers in IBMcloud.

Three separate layouts of clusters can be deployed:

* BM - Bare Metal - 3 control-plane nodes, X number of worker nodes
* RWN - Remote Worker Node - 3 control-plane/worker nodes, X number of remote worker nodes
* SNO - Single Node OpenShift - 1 OpenShift Master/Worker Node "cluster" per available hardware resource

Each cluster layout requires a bastion machine which is the first machine out of your lab "cloud" allocation. The bastion machine will host the assisted-installer and serve as a router for clusters with a private machine network. BM and RWN layouts produce a single cluster consisting of 3 control-plane nodes and X number of worker or remote worker nodes. SNO layout creates an SNO cluster per available machine after fulfilling the bastion machine requirement. Lastly, BM/RWN cluster types will allocate any unused machines under the `hv` ansible group which stands for hypervisor nodes. This allows quicker interaction with these extra nodes in a lab allocation.

_**Table of Contents**_

<!-- TOC -->
- [Tested Labs/Hardware](#tested-labshardware)
- [Prerequisites](#prerequisites)
- [Cluster Deployment Usage](#cluster-deployment-usage)
- [Quickstart guides](#quickstart-guides)
- [Troubleshooting](#troubleshooting)
- [Disconnected API/Console Access](#disconnected-apiconsole-access)
- [Hypervisor Network-Impairments](#hypervisor-network-impairments)
<!-- /TOC -->

## Tested Labs/Hardware

**Alias Lab**

| Hardware | BM  | RWN | SNO |
| -------- | --- | --- | --- |
| 740xd    | No  | No  | Yes |

**Scale Lab**

| Hardware           | BM  | RWN | SNO |
| ------------------ | --- | --- | --- |
| Dell r640          | Yes | Yes | Yes |
| Dell fc640         | No  | No  | Yes |
| Supermicro 1029p * | Yes | Yes | No  |

*Note Hardware/Cluster Deployment Type may require some manual interaction to complete an install

**IBMcloud**

| Hardware                 | BM  | SNO |
| -------------------------| --- | --- |
| Supermicro E5-2620       | Yes | Yes |
| Lenovo ThinkSystem SR630 | No  | Yes |


## Prerequisites

Versions:

* Ansible 2.10 (on machine running jetlag playbooks)
* ibmcloud cli => 2.0.1 (IBMcloud environments)
* RHEL 8.4 / Centos 8.4 (Bastion)
* podman 3 (Bastion)

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](docs/order-hardware-ibmcloud.md) in [docs](docs) directory.

Pre-reqs for the playbooks:

```console
ansible-galaxy collection install ansible.netcommon
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
ansible-galaxy collection install containers.podman
```

```console
pip3 install netaddr python-hpilo
```

## Cluster Deployment Usage

There are three main files to configure and one is generated but might have to be edited for specific desired scenario/hardware usage:

* `ansible/vars/all.yml` - An ansible vars file (Sample provided `ansible/vars/all.sample.yml`)
* `pull_secret.txt` - Your OCP pull secret
* `ansible/inventory/$CLOUDNAME.local` - The generated inventory file (Samples provided in `ansible/inventory`)

Start by editing the vars

```console
cp ansible/vars/all.sample.yml ansible/vars/all.yml
vi ansible/vars/all.yml
```

Make sure to set/review the following vars:

* `lab` - either `alias` or `scalelab`
* `lab_cloud` - the cloud within the lab environment (Example: `cloud42`)
* `cluster_type` - either `bm`, `rwn`, or `sno` for the respective cluster layout
* `worker_node_count` - applies to bm and rwn cluster types for the desired worker count, ideal for leaving left over inventory hosts for other purposes
* `public_vlan` - applies to sno cluster_types, set to be `true` only for public routable vlan deployment
* `controlplane_lab_interface` - applies to bm and rwn cluster types and should map to the nodes interface in which the lab provides dhcp to and also required for public routable vlan based sno deployment(to disable this interface)
* `controlplane_network_interface` - applies to bm and rwn cluster types and should map to the nodes interface in which the cluster(controlplane apis) needs to be hosted on and also required for public routable vlan based sno deployment
* `controlplane_pub_network_cidr` and `controlplane_pub_network_gateway` - only required for public routable vlan based sno deployment to input lab public routable vlan network and gateway
* `rwn_lab_interface` - applies only to rwn cluster type and should map to the nodes interface in which the lab provides dhcp to
* More customization like cluster_network, service_network, rwn_vlan and rwn_networks can be supported as extra vars, check default files for variable name.

Set your pull-secret in `pull_secret.txt` in repo base directory.

Run create-inventory playbook

```console
ansible-playbook ansible/create-inventory.yml
```

Run setup-bastion playbook

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/setup-bastion.yml
```

Run deploy for either bm/rwn/sno playbook with inventory created by create-inventory playbook

Bare Metal Cluster:

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/bm-deploy.yml
```

Remote Worker Node Cluster:

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/rwn-deploy.yml
```

Single Node OpenShift:

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/sno-deploy.yml
```

## Quickstart guides

* [Deploy a Bare Metal cluster via jetlag quickstart guide](docs/deploy-bm-quickstart.md)
* [Deploy a Bare Metal cluster on IBMcloud via jetlag quickstart](docs/deploy-bm-ibmcloud.md)
* [Deploy Single Node OpenShift clusters on IBMcloud via jetlag quickstart](docs/deploy-sno-ibmcloud.md)

## Troubleshooting

See [troubleshooting.md](docs/troubleshooting.md) in [docs](docs) directory.

## Disconnected API/Console Access

See [disconnected-ipv6-cluster-access.md](docs/disconnected-ipv6-cluster-access.md) in [docs](docs) directory.

## Hypervisor Network-Impairments

See [hypervisor-network-impairments.md](docs/hypervisor-network-impairments.md) in [docs](docs) directory.

## Workload Usage

The jetlag workload has moved into a new repo and renamed [boatload](https://github.com/akrzos/boatload).
