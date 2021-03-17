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
$ ansible-galaxy collection install ansible.posix
$ ansible-galaxy collection install containers.podman
$ ansible-galaxy collection install community.general
```

## Usage

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

Run deploy playbook with inventory created by create-inventory playbook

```console
ansible-playbook -i ansible/inventory/cloud42.local ansible/deploy.yml
```
