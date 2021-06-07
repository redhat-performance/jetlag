# jetlag

Tooling to install clusters for testing via an on-prem [Assisted Installer](https://github.com/openshift/assisted-installer) on the Scale lab or Alias lab hardware.

Three separate layouts of clusters can be deployed:

* BM - Baremetal - 3 control-plane nodes, X number of worker nodes
* RWN - Remote Worker Node - 3 control-plane/worker nodes, X number of remote worker nodes
* SNO - Single Node OpenShift - 1 OpenShift Master/Worker Node "cluster" per available hardware resource

Each cluster layout requires a bastion machine which is the first machine out of your lab "cloud" allocation. The bastion machine will host the assisted-installer and serve as a router for remote worker node clusters. BM and RWN layouts produce a single cluster consisting of 3 control-plane nodes and X number of worker or remote worker nodes. SNO layout creates an SNO cluster per available machine after fufilling the bastion machine requirement. Lastly, BM/RWN cluster types will allocate any unused machines under the `hv` ansible group which stands for hypervisor nodes. This allows quicker interaction with these extra nodes in a lab allocation.

## Tested Labs/Hardware

Alias Lab

| Hardware | BM  | RWN | SNO |
| -------- | --- | --- | --- |
| 740xd    | No  | No  | Yes |

Scale Lab

| Hardware         | BM  | RWN | SNO |
| ---------------- | --- | --- | --- |
| Dell r640        | Yes | Yes | Yes |
| Dell fc640       | No  | No  | Yes |
| Supermicro 1029p | Yes | Yes | No  |

## Ansible Prerequisites

Pre-reqs for the playbooks:

```console
$ ansible-galaxy collection install ansible.posix
$ ansible-galaxy collection install containers.podman
$ ansible-galaxy collection install community.general
```

```console
pip3 install netaddr
```

## Cluster Deployment Usage

There are three main files to configure and one is generated but might have to be edited for specific desired scenario/hardware usage:

* `ansible/vars/all.yml` - An ansible vars file (Sample provided `ansible/vars/all.sample.yml`)
* `pull_secret.txt` - Your OCP pull secret
* `ansible/inventory/$CLOUDNAME.local` - The generated inventory file (Samples provided in `ansible/inventory`)

Start by editing the vars

```console
$ cp ansible/vars/all.sample.yml ansible/vars/all.yml
$ vi ansible/vars/all.yml
```

Make sure to set/review the following vars:

* `lab` - either `alias` or `scalelab`
* `lab_cloud` - the cloud within the lab environment (Example: `cloud42`)
* `cluster_type` - either `bm`, `rwn`, or `sno` for the respective cluster layout
* `worker_node_count` - applies to bm and rwn cluster types for the desired worker count, ideal for leaving left over inventory hosts for other purposes
* `controlplane_lab_interface` - applies to bm and rwn cluster types and should map to the nodes interface in which the lab provides dhcp to
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

## Hypervisor Network-Impairments

BM/RWN cluster types will allocate remaining hardware that was not put in the inventory for the cluster as Hypervisor nodes. For testing where network impairments is required, we can apply latency/packet-loss/bandwidth impairments on the hypervisor nodes.

In order to do so, first copy the network-impairments sample vars file

```console
$ cp ansible/vars/network-impairments.sample.yml ansible/vars/network-impairments.yml
$ vi ansible/vars/network-impairments.yml
```

Make sure to set/review the following vars:

* `install_tc` - toggles installing traffic control
* `apply_egress_impairments` and `apply_ingress_impairments` - toggles out-going or incoming traffic impairments
* `impaired_nic` - nic for traffic impairments
* `egress_delay` and `ingress_delay` - latency for egress/ingress in milliseconds
* `egress_packet_loss` and `ingress_packet_loss` - packet loss in percent (Example `0.01` for 0.01%)
* `egress_bandwidth` and `ingress_bandwidth` - bandwidth in kilobits (Example `100000` which is 100000kbps or 100Mbps)

Apply impairments:

```console
ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml
```

Remove impairments:

```console
ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml -e 'apply_egress_impairments=false apply_ingress_impairments=false'
```

Note, egress impairments are applied directly to the impaired nic. Ingress impairments are applied to an ifb interface that handles ingress traffic for the impaired nic.

## Workload Usage

Review README.md in [workload](workload) directory.
