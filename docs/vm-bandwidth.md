# VM Bandwidth Limiting

Jetlag provides two mechanisms for controlling VM network bandwidth: static limits applied at VM creation time via the libvirt domain XML, and dynamic limits applied to existing VMs via `virsh domiftune`.

> **Note:** Bandwidth limits are applied per VM network interface. This is primarily intended for SNO deployments where each VM represents a single-node OpenShift cluster, allowing you to simulate low-bandwidth edge environments. Applying per-VM bandwidth limits to VMs that form a multi-node cluster (VMNO) will constrain each node individually, which may not accurately represent a shared network bottleneck.

_**Table of Contents**_

<!-- TOC -->
- [VM Bandwidth Limiting](#vm-bandwidth-limiting)
  - [Creation-time bandwidth limits](#creation-time-bandwidth-limits)
    - [Variables](#variables)
    - [Enabling creation-time limits](#enabling-creation-time-limits)
    - [Changing creation-time limits after inventory generation](#changing-creation-time-limits-after-inventory-generation)
  - [Dynamic bandwidth limits](#dynamic-bandwidth-limits)
    - [Overview](#overview)
    - [Apply a bandwidth limit](#apply-a-bandwidth-limit)
    - [Remove a bandwidth limit](#remove-a-bandwidth-limit)
  - [Bandwidth reference](#bandwidth-reference)
  - [Interaction between creation-time and dynamic limits](#interaction-between-creation-time-and-dynamic-limits)
    - [VMs created without bandwidth limits](#vms-created-without-bandwidth-limits)
    - [VMs created with bandwidth limits](#vms-created-with-bandwidth-limits)
<!-- /TOC -->

## Creation-time bandwidth limits

Bandwidth limits can be baked into the libvirt domain XML at VM creation time. When enabled, the limits are applied as part of `hv-vm-create.yml` (or `hv-vm-replace.yml`) and persist as long as the VM definition exists.

### Variables

The following variables control creation-time bandwidth limits and are defined in `ansible/roles/create-inventory/defaults/main/main.yml`. Override them in the `Extra vars` section of `ansible/vars/all.yml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `hv_vm_bandwidth_limit` | `false` | Enable bandwidth limiting on VM network interfaces |
| `hv_vm_bandwidth_average` | `11500` | Average bandwidth in KB/s (~92 Mbit/s) |
| `hv_vm_bandwidth_peak` | `12500` | Peak bandwidth in KB/s (~100 Mbit/s) |
| `hv_vm_bandwidth_burst` | `11750` | Burst bandwidth in KB/s (~94 Mbit/s) |

### Enabling creation-time limits

Set the following in the `Extra vars` section of `ansible/vars/all.yml` before running `create-inventory.yml`:

```yaml
################################################################################
# Extra vars
################################################################################
hv_vm_bandwidth_limit: true

# Optional: override the default bandwidth values (in KB/s)
# hv_vm_bandwidth_average: 11500
# hv_vm_bandwidth_peak: 12500
# hv_vm_bandwidth_burst: 11750
```

Then regenerate the inventory and create VMs:

```console
[root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml
```

The bandwidth limits are written into each VM's inventory entry and applied to the libvirt domain XML `<bandwidth>` element during VM creation.

### Changing creation-time limits after inventory generation

The bandwidth values (`bw_avg`, `bw_peak`, `bw_burst`) are baked into the generated inventory file when `create-inventory.yml` runs. To change the limits for future VMs, update the variables in `ansible/vars/all.yml` and rerun `create-inventory.yml` to regenerate the inventory.

You can also edit the generated inventory file directly (e.g., `ansible/inventory/cloud99.local`) to apply different bandwidth limits to individual VMs. Each VM entry in the `[hv_vm]` section has `bw_avg`, `bw_peak`, and `bw_burst` values that can be adjusted independently. This is useful when you want to simulate a mix of bandwidth conditions across VMs, for example testing a fleet of SNOs with varying link speeds.

## Dynamic bandwidth limits

### Overview

The `hv-vm-bandwidth.yml` playbook uses `virsh domiftune` to dynamically apply or remove bandwidth limits on VMs managed by Jetlag. It works on both running and powered-off VMs:

- **Running VMs**: The limit is applied immediately and persisted to the VM definition so it survives reboots.
- **Powered-off VMs**: The limit is persisted to the VM definition and takes effect on the next start.

The playbook accepts a single extra variable `vm_bandwidth` specified in **Mbit/s**. The value maps to the peak bandwidth, with average (92%) and burst (94%) computed automatically to match the ratios used by the creation-time defaults.

### Apply a bandwidth limit

Pass `vm_bandwidth` with the desired limit in Mbit/s:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-bandwidth.yml -e vm_bandwidth=100
```

### Remove a bandwidth limit

Pass `vm_bandwidth=0` to remove any existing limit:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-bandwidth.yml -e vm_bandwidth=0
```

If `vm_bandwidth` is omitted, it defaults to `0` (remove limits).

## Bandwidth reference

The following table shows the dynamic `vm_bandwidth` value (Mbit/s) and the corresponding creation-time inventory variables (`bw_avg`, `bw_peak`, `bw_burst` in KB/s) for common bandwidth targets.

| `vm_bandwidth` | Throughput | `bw_avg` | `bw_peak` | `bw_burst` |
| --------------:| ---------- | -------: | --------: | ---------: |
| 1 | 1 Mbit/s (~125 KB/s) | 115 | 125 | 117 |
| 10 | 10 Mbit/s (~1.2 MB/s) | 1150 | 1250 | 1175 |
| 20 | 20 Mbit/s (~2.5 MB/s) | 2300 | 2500 | 2350 |
| 100 | 100 Mbit/s (~12.5 MB/s) | 11500 | 12500 | 11750 |
| 1000 | 1 Gbit/s (~125 MB/s) | 115000 | 125000 | 117500 |
| 0 | No limit (remove) | - | - | - |

## Interaction between creation-time and dynamic limits

The `hv-vm-bandwidth.yml` playbook works regardless of whether creation-time limits were used.

### VMs created without bandwidth limits

When `hv_vm_bandwidth_limit` is `false` (the default), VMs are created with no bandwidth restrictions. Running `hv-vm-bandwidth.yml` with a `vm_bandwidth` value adds a limit where none existed before. This is useful for testing bandwidth-constrained scenarios on VMs that were originally deployed without limits.

### VMs created with bandwidth limits

When `hv_vm_bandwidth_limit` is `true`, VMs are created with bandwidth limits defined in the libvirt domain XML. Running `hv-vm-bandwidth.yml` **overrides** those creation-time limits with the new value. Setting `vm_bandwidth=0` removes the limit entirely, even if the VM was originally created with one. Note that `hv-vm-replace.yml` will recreate VMs with whatever limits are defined in the inventory, so creation-time settings are restored on VM replacement.
