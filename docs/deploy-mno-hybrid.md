# Deploy Multi-Node OpenShift Hybrid in ScaleLab

This guide describes how to deploy a hybrid Multi-Node OpenShift (MNO) cluster in ScaleLab: some nodes are bare metal and some are virtual machines (VMs).

## 1. Configure Ansible variables in `all.yml`

Set up `all.yml` the same way as for a standard ScaleLab allocation. Then add these variables:

```
cluster_type: mno           # Use "mno" (not "vmno"). MNO allows bare metal nodes; VMNO does not.
hv_inventory: true
hv_ssh_pass: <hv-password>
hybrid_worker_count: 123    # Total number of VM workers you want.
```

**Why use two phases?**  
First you install a small cluster and confirm it works. Then you add the VM workers. Doing it in two steps makes it easier to find and fix problems: issues from the first install are separate from issues when creating many VMs.

## 2. Run the playbooks

### Phase 1: Install a small cluster (3 control-plane + 3 workers)

1. In `all.yml`, set `hybrid_worker_count: 0`.
2. Run the `create-inventory.yml` playbook.
3. Run the `mno-deploy.yml` playbook.
4. Run the `hv-setup.yml` playbook.

### Phase 2: Add the VM workers

1. In `all.yml`, set `hybrid_worker_count: 123`.
2. Run the `create-inventory.yml` playbook.
3. Open the inventory file at `ansible/inventory/cloudXX.local`. Check:
   - **`[worker]`**: It should list the bare metal workers and the correct number of VMs to create.
   - **`[hv_vm]`**: It should list the expected number of VMs with the right CPU, memory, and disk. Confirm how many VMs are assigned to each hypervisor (HV). This ratio is set by machine type in `hw_vm_counts` in `lab.yml`.
4. Run the `hv-vm-create.yml` playbook. For more about this playbook, see [Virtual MultiNode OpenShift](deploy-vmno.md).
5. Run the `ocp-scale-out.yml` playbook. For more about this playbook, see [Scale out a Multi-Node OpenShift deployment](scale-out-mno.md).

## Command reference

### create-inventory.yml

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
```

### hv-setup.yml

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml
```

### hv-vm-create.yml

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml
```

### mno-deploy.yml

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
```

### ocp-scale-out.yml

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/ocp-scale-out.yml
```