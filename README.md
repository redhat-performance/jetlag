# jetlag

Tooling to install RWN and SNO clusters for testing via the [Assisted Installer](https://github.com/openshift/assisted-installer).


## RWN/SNO Prerequisites

Pre-reqs for the playbooks:

```console
$ ansible-galaxy collection install ansible.posix
$ ansible-galaxy collection install containers.podman
$ ansible-galaxy collection install community.general
```

## RWN Network Prerequisites

* Network layout for RWN testing
* VLAN interfaces on bastion machine

## Cluster Deployment Usage

Edit vars

```console
$ cp ansible/vars/all.sample.yml ansible/vars/all.yml
$ vi ansible/vars/all.yml
```

Copy your pull-secret into `pull_secret.txt` in repo base directory.

Run create-inventory playbook

```console
ansible-playbook ansible/create-inventory.yml
```

Run setup-bastion playbook

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/setup-bastion.yml
```

Run deploy for either rwn/sno playbook with inventory created by create-inventory playbook

Remote Worker Node Cluster:

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/rwn-deploy.yml
```

Single Node OpenShift:

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/sno-deploy.yml
```

## Workload Usage

Review README.md in [workload](workload) directory.
