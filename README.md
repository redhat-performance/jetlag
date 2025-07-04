# Jetlag

Tooling to install clusters for testing via an on-prem [Assisted Installer](https://github.com/openshift/assisted-installer) in the Red Hat Scale Lab, Red Hat Performance Lab, and IBMcloud (Bare Metal).

Two types of clusters can be deployed:

| Layout | Meaning | Description |
| - | - | - |
| MNO | Multi Node OpenShift | 3 control-plane nodes, X number of worker nodes
| SNO | Single Node OpenShift | 1 OpenShift Master/Worker Node "cluster" per available hardware resource

Both cluster layouts require a bastion machine which is the first machine out of your lab "cloud" allocation. The bastion machine will host the assisted-installer service and serve as a router for clusters with a private machine network. MNO layout produces a single cluster consisting of 3 control-plane nodes and X number of worker nodes. The worker node count can also be 0 such that your multi node cluster is a compact 3 node cluster with schedulable control-plane nodes. SNO layout creates an SNO cluster per available machine after fulfilling the bastion machine requirement. Lastly, MNO cluster type will allocate any unused machines under the `hv` ansible group which stands for hypervisor nodes. The `hv` nodes can host vms for additional clusters that can be deployed from the hub cluster. (For ACM/MCE testing)

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

The listed hardware has been used for cluster deployments successfully. Potentially other hardware has been tested but not documented here.

**Performance Lab**

| Hardware | MNO | SNO |
| -------- | --- | --- |
| 740xd    | Yes | Yes |
| Dell r750| Yes | Yes |

**Scale Lab**

| Hardware           | MNO | SNO |
| ------------------ | --- | --- |
| Dell r750          | Yes | No  |
| Dell r660          | Yes | Yes |
| Dell r650          | Yes | Yes |
| Dell r640          | Yes | Yes |
| Dell r630          | Yes | Yes |
| Dell fc640         | Yes | Yes |
| Supermicro 1029p   | Yes | No  |
| Supermicro 1029U   | Yes | Yes |
| Supermicro 5039ms  | Yes | Yes |

**IBMcloud**

| Hardware                 | MNO | SNO |
| -------------------------| --- | --- |
| Supermicro E5-2620       | Yes | Yes |
| Lenovo ThinkSystem SR630 | Yes | Yes |

For guidance on how to order hardware on IBMcloud, see [order-hardware-ibmcloud.md](docs/order-hardware-ibmcloud.md) in [docs](docs) directory.

## Prerequisites

Versions:

* Ansible 4.10+ (core >= 2.11.12) (on machine running jetlag playbooks)
* ibmcloud cli => 2.0.1 (IBMcloud environments)
* ibmcloud plugin install sl (IBMcloud environments)
* RHEL >= 8.6 (Bastion)
* podman 3 / 4 (Bastion)

Installing Ansible via bootstrap (requires python3-pip)

```console
[root@<bastion> jetlag]# source bootstrap.sh
...
(.ansible) [root@<bastion> jetlag]#
```

Pre-reqs for Supermicro hardware:

* [SMCIPMITool](https://www.supermicro.com/SwDownload/SwSelect_Free.aspx?cat=IPMI) downloaded to jetlag repo, renamed to `smcipmitool.tar.gz`, and placed under `ansible/`

## Cluster Deployment Usage

We recommend that you set up Jetlag on the bastion machine and run playbooks
from there. This will give faster access to the machines being configured, and
it also provides an environment that can easily be shared for debugging if
necessary. However you can run Jetlag playbooks from a remote host (for example,
your laptop) as long as you can connect to the bastion machine in your cloud
allocation.

There are three main files to configure. The inventory file is generated and can be edited for specific scenario/hardware usage.
You can also [manually create a "Bring Your Own Lab"](docs/deploy-mno-byol.md) inventory file.

| File | Description |
| - | - |
| `ansible/vars/all.yml` | An Ansible vars file used for Red Hat performance labs (sample provided at `ansible/vars/all.sample.yml`)
| `ansible/vars/ibmcloud.yml` | An Ansible vars file used for IBM Cloud (sample provided at `ansible/vars/ibmcloud.sample.yml`)
| `pull_secret.txt` | Your OCP pull secret, download from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads)
| `ansible/inventory/$CLOUDNAME.local` | The generated inventory file (Samples provided in `ansible/inventory`)

Start by editing the vars

**Red Hat performance labs**

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/all.sample.yml ansible/vars/all.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/all.yml
```

**IBM Cloud**

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/ibmcloud.sample.yml ansible/vars/ibmcloud.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/ibmcloud.yml
```

Make sure to set/review the following vars:

| Variable | Meaning |
| - | - |
| `lab` | `performancelab`, `scalelab`, or `ibmcloud`
| `lab_cloud` | the cloud within the lab environment for Red Hat Performance labs (Example: `cloud42`)
| `cluster_type` | either `mno`, or `sno` for the respective cluster layout
| `worker_node_count` | applies to mno cluster type for the desired worker count, ideal for leaving left over inventory hosts for other purposes
| `hybrid_worker_count` | applies to mno cluster type for the desired virtual worker count, HV nodes and VMs are required to be setup.
| `bastion_lab_interface` | set to the bastion machine's lab accessible interface
| `bastion_controlplane_interface` | set to the interface in which the bastion will be networked to the deployed ocp cluster
| `controlplane_lab_interface` | applies to mno cluster type and should map to the nodes interface in which the lab provides dhcp to and also required for public routable vlan based sno deployment(to disable this interface)

More customization such as `cluster_network` and `service_network` are available as extra vars, check each ansible role default vars file for variable names and options.

Save your pull-secret from [console.redhat.com/openshift/downloads](https://console.redhat.com/openshift/downloads) in `pull_secret.txt` in the Jetlag repo base directory, for example by using the "Copy" button on the web page, and then pasting the clipboard text into a `cat > pull_secret.txt` command like this:

```console
(.ansible) [root@<bastion> jetlag]# cat >pull_secret.txt
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

Run create-inventory playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
```

Run setup-bastion playbook

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
```

Run deploy for either mno/sno playbook with inventory created by create-inventory playbook

Multi Node OpenShift Cluster:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
```
See [troubleshooting.md](https://github.com/redhat-performance/jetlag/blob/main/docs/troubleshooting.md) in [docs](https://github.com/redhat-performance/jetlag/tree/main/docs) directory for MNO install related issues

Single Node OpenShift:

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/sno-deploy.yml
```

Interact with your cluster from your bastion machine:

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/mno/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
NAME               STATUS   ROLES                         AGE    VERSION
xxx-h02-000-r650   Ready    control-plane,master,worker   73m    v1.25.7+eab9cc9
xxx-h03-000-r650   Ready    control-plane,master,worker   103m   v1.25.7+eab9cc9
xxx-h05-000-r650   Ready    control-plane,master,worker   105m   v1.25.7+eab9cc9
(.ansible) [root@<bastion> jetlag]# cat /root/mno/kubeadmin-password
xxxxx-xxxxx-xxxxx-xxxxx
```

And for SNO

```console
(.ansible) [root@<bastion> jetlag]# export KUBECONFIG=/root/sno/xxx-h02-000-r650/kubeconfig
(.ansible) [root@<bastion> jetlag]# oc get no
NAME      STATUS   ROLES                         AGE   VERSION
xxx-h02-000-r650   Ready    control-plane,master,worker   30h   v1.28.6+0fb4726
(.ansible) [root@<bastion> jetlag]# cat /root/sno/xxx-h02-000-r650/kubeadmin-password
xxxxx-xxxxx-xxxxx-xxxxx
```

## Quickstart guides

* [Deploy a Multi Node OpenShift cluster via jetlag from a Scale Lab Bastion Machine](docs/deploy-mno-scalelab.md)
* [Deploy a Multi Node OpenShift cluster via jetlag from a Performance Lab Bastion Machine](docs/deploy-mno-performancelab.md)
* [Deploy a Multi Node OpenShift cluster on IBMcloud via jetlag](docs/deploy-mno-ibmcloud.md)
* [Deploy Single Node OpenShift (SNO) clusters via jetlag from a Scale Lab Bastion Machine](docs/deploy-sno-scalelab.md)
* [Deploy Single Node OpenShift (SNO) clusters via jetlag from a Performance Lab Bastion Machine](docs/deploy-sno-performancelab.md)
* [Deploy Single Node OpenShift (SNO) clusters via jetlag on IBMcloud ](docs/deploy-sno-ibmcloud.md)
* [Deploy a VMNO](docs/deploy-vmno.md)
* [Scale up MNO](docs/scale-out-mno.md)

## Tips and Troubleshooting

See [tips-and-vars.md](docs/tips-and-vars.md) in [docs](docs) directory.

See [troubleshooting.md](docs/troubleshooting.md) in [docs](docs) directory.

## Disconnected API/Console Access

See [disconnected-ipv6-cluster-access.md](docs/disconnected-ipv6-cluster-access.md) in [docs](docs) directory.

## Jetlag Hypervisors

See [hypervisors.md](docs/hypervisors.md) in [docs](docs) directory.
