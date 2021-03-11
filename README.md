# rwn-ai-deploy

Creates a bare metal three node master/worker cluster via the Assisted Installer. Subsequent remote worker nodes are added by a livecd install.

## Prerequisites

* Network layout for RWN testing
* FRR routing on bastion machine
* VLAN interfaces on bastion machine
* Assisted Installer running on bastion machine
* HTTP server running on bastion machine

Prereqs for the playbooks:

```console
$ ansible-galaxy collection install containers.podman
$ ansible-galaxy collection install community.general
```

## Usage

Edit vars

```console
$ cp vars/all.sample.yml vars/all.yml
$ vi vars/all.yml
```

Run create-inventory playbook

```console
ansible-playbook create-inventory.yml
```

Run deploy playbook with inventory created by create-inventory playbook

```console
ansible-playbook -i inventory/cloud42.local deploy.yml
```
