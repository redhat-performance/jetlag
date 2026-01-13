# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Jetlag is an OpenShift cluster deployment tool that uses Ansible automation to deploy Multi Node OpenShift (MNO) and Single Node OpenShift (SNO) clusters via the Assisted Installer. It supports Red Hat performance labs, Scale Labs, and IBMcloud environments.

## Essential Commands

### Environment Setup
```bash
# Bootstrap ansible virtual environment (run from repo root)
source bootstrap.sh

# Red Hat Labs (Scale Lab/Performance Lab)
# Copy and edit configuration file
cp ansible/vars/all.sample.yml ansible/vars/all.yml
# Edit all.yml with your lab configuration (lab, lab_cloud, cluster_type, etc.)

# Create inventory file for your lab environment
ansible-playbook ansible/create-inventory.yml
# Setup bastion host (replace cloud99.local with your inventory file)
ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml

# IBMcloud
# Copy and edit configuration file
cp ansible/vars/ibmcloud.sample.yml ansible/vars/ibmcloud.yml
# Edit ibmcloud.yml with your IBMcloud configuration (cluster_type, worker_node_count, etc.)

# Create inventory file from IBMcloud CLI data
ansible-playbook ansible/ibmcloud-create-inventory.yml
# Setup bastion host for IBMcloud
ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml
```

### Cluster Deployment
```bash
# Red Hat Labs (Scale Lab/Performance Lab)
# Deploy Multi Node OpenShift cluster
ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml

# Deploy Single Node OpenShift clusters
ansible-playbook -i ansible/inventory/cloud99.local ansible/sno-deploy.yml

# Deploy Virtual Multi Node OpenShift (VMNO) - requires hypervisor setup first
ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml
ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml
ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml

# IBMcloud
# Deploy Multi Node OpenShift on IBMcloud
ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-mno-deploy.yml

# Deploy Single Node OpenShift on IBMcloud
ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-sno-deploy.yml
```

### Cluster Management
```bash
# Scale out MNO cluster
ansible-playbook ansible/ocp-scale-out.yml

# Setup hypervisor nodes for VMs
ansible-playbook ansible/hv-setup.yml

# Create VMs on hypervisor nodes
ansible-playbook ansible/hv-vm-create.yml

# Delete VMs from hypervisor nodes
ansible-playbook ansible/hv-vm-delete.yml

# Replace VMs on hypervisor nodes (delete + recreate)
ansible-playbook ansible/hv-vm-replace.yml

# Sync OpenShift releases
ansible-playbook ansible/sync-ocp-release.yml
```

## Project Architecture

### Key Configuration Files
- `ansible/vars/all.yml` - Main configuration for Red Hat labs (copy from `ansible/vars/all.sample.yml`)
- `ansible/vars/ibmcloud.yml` - IBMcloud-specific configuration (copy from `ansible/vars/ibmcloud.sample.yml`)
- `pull-secret.txt` - OpenShift pull secret (place in repo root)
- `ansible/inventory/$CLOUDNAME.local` - Generated inventory file for your lab

### Critical Variables
- `lab`: Environment type (`performancelab`, `scalelab`, or `ibmcloud`)
- `lab_cloud`: Specific cloud allocation (e.g., `cloud42`)
- `cluster_type`: Either `mno`, `sno`, or `vmno`
- `worker_node_count`: Number of bare metal worker nodes for MNO clusters
- `hybrid_worker_count`: Number of virtual worker nodes for hybrid MNO clusters (requires hypervisor setup)
- `ocp_build`: OpenShift build type (`ga`, `dev`, or `ci`)
- `ocp_version`: OpenShift version (e.g., `latest-4.20`)

### Ansible Role Structure
Jetlag uses a modular Ansible role architecture:

- **Bastion roles**: `bastion-*` roles configure the bastion host with services like Assisted Installer, DNS, registry
- **Installation roles**: `install-cluster`, `sno-post-cluster-install` handle cluster deployment
- **Hypervisor roles**: `hv-*` roles manage VM infrastructure on hypervisor nodes
- **Utility roles**: `boot-iso`, `sync-*` roles provide supporting functionality

### Cluster Types
- **MNO (Multi Node OpenShift)**: 3 control-plane nodes + configurable bare metal worker nodes
- **SNO (Single Node OpenShift)**: Single node clusters, one per available machine
- **VMNO (Virtual Multi Node OpenShift)**: MNO cluster using VMs instead of bare metal (Jetlag-specific term)
- **Hybrid MNO**: MNO cluster with both bare metal and virtual worker nodes

#### Virtual and Hybrid Cluster Details
- **VMNO clusters** allow multi-node deployment with fewer physical machines (minimum: 1 bastion + 1-2 hypervisors)
- **Hybrid clusters** combine bare metal workers (`worker_node_count`) with virtual workers (`hybrid_worker_count`)
- **Hypervisor nodes**: Unused machines become VM hosts for additional clusters or hybrid workers
- Virtual workers are created as VMs on hypervisor nodes and added to the worker inventory section
- VM placement distributed across available hypervisors based on hardware-specific VM count configurations

### Lab Environment Support
- **Performance Lab**: Dell r750, 740xd hardware
- **Scale Lab**: Various Dell models (r750, r660, r650, r640, r630, fc640), Supermicro systems
- **IBMcloud**: Supermicro E5-2620, Lenovo SR630 bare metal

## Development Workflow

### Standard MNO/SNO Deployment (Red Hat Labs)
1. Edit `ansible/vars/all.yml` with your lab configuration
2. Run `ansible-playbook ansible/create-inventory.yml` to generate inventory
3. Run `ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml` to configure bastion host
4. Run deployment playbook (`ansible/mno-deploy.yml` or `ansible/sno-deploy.yml`)
5. Access clusters using kubeconfig files in `/root/mno/` or `/root/sno/`

### IBMcloud MNO/SNO Deployment
1. Edit `ansible/vars/ibmcloud.yml` with your IBMcloud configuration
2. Run `ansible-playbook ansible/ibmcloud-create-inventory.yml` to generate `ansible/inventory/ibmcloud.local` from IBMcloud CLI data
3. Run `ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-setup-bastion.yml` to configure bastion host
4. Run deployment playbook (`ansible-playbook -i ansible/inventory/ibmcloud.local ansible/ibmcloud-mno-deploy.yml` or `ansible/ibmcloud-sno-deploy.yml`)
5. Access clusters using kubeconfig files in `/root/mno/` or `/root/sno/`

### VMNO Deployment (Red Hat Labs Only)
1. Edit `ansible/vars/all.yml` with `cluster_type: vmno` and VM-specific settings
2. Edit `ansible/vars/hv.yml` for hypervisor configuration
3. Run `ansible-playbook ansible/create-inventory.yml` to generate inventory with VM entries
4. Run `ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml` to configure bastion host
5. Run `ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml` to configure hypervisor nodes
6. Run `ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml` to create VMs
7. Run `ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml` to deploy cluster to VMs
8. Access cluster using kubeconfig in `/root/vmno/`

### Hybrid Cluster Deployment (Red Hat Labs Only)
1. Configure both `worker_node_count` (bare metal) and `hybrid_worker_count` (VMs) in `ansible/vars/all.yml`
2. Ensure hypervisor nodes are available in allocation
3. Follow standard Red Hat Labs MNO workflow - hybrid workers automatically added to inventory

## Special Considerations

- Inventory files are generated, not manually created (except for "Bring Your Own Lab" scenarios)
- Bastion machine is always the first machine in allocation and hosts Assisted Installer
- Unused machines in MNO deployments become hypervisor nodes
- SNO deployments create one cluster per available machine after bastion
- Public VLAN support available for routable environments (`public_vlan: true`)
- Disconnected/air-gapped deployments supported with registry mirroring

### Virtual and Hybrid Cluster Considerations
- **Hardware Requirements**: VMNO requires additional CPU/memory capacity for VM overhead
- **VM Management**: Use `hv-vm-delete.yml` or `hv-vm-replace.yml` between VMNO deployments to avoid conflicts
- **Resource Planning**: Configure `hw_vm_counts` per hardware type to optimize VM distribution across hypervisors
- **Disk Configuration**: VMs can span multiple disks on hypervisors (e.g., default disk + nvme for higher VM counts)
- **Network Configuration**: VMs use libvirt networking with static IP assignment from controlplane network range
- **Scale Lab/Performance Lab Only**: VMNO and hybrid deployments only supported in Scale Lab and Performance Lab environments