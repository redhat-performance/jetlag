# rwn-ai-deploy

Creates a baremetal three node master/worker cluster via the Assisted Installer. Subsequent remote workers are added by a livecd install.

## Prerequisites

```console
ansible-galaxy collection install community.general
```

## Usage

Edit vars

```console
$ cp vars/all.sample.yml vars/all.yml
$ vi vars/all.yml
```

Create inventory file via playbook

```console
ansible-playbook create-inventory.yml
```

Run deploy playbook

```console
ansible-playbook -i inventory/cloud42.local deploy.yml
```
