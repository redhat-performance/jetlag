# Local Storage

Jetlag can configure the [OpenShift Local Storage Operator (LSO)](https://docs.openshift.com/container-platform/latest/storage/persistent_storage/persistent_storage_local/persistent-storage-local.html) on control-plane and worker nodes during cluster deployment. Disk preparation (wiping, partitioning, LVM setup) is handled via Ignition at node boot time. LSO is then installed and `LocalVolume` resources are created post-install.

_**Table of Contents**_

<!-- TOC -->
- [Local Storage](#local-storage)
  - [Variables](#variables)
  - [Disk types](#disk-types)
    - [LVM disks](#lvm-disks)
    - [Plain disks](#disk-disks)
  - [LocalVolume resources](#localvolume-resources)
  - [Configuration examples](#configuration-examples)
    - [Control-plane with LVM only](#control-plane-with-lvm-only)
    - [Control-plane with LVM and disk disks](#control-plane-with-lvm-and-disk-disks)
    - [Workers with LVM](#workers-with-lvm)
    - [Wipe only, no LSO](#wipe-only-no-lso)
<!-- /TOC -->

## Variables

All variables are defined in `ansible/roles/configure-local-storage/defaults/main.yml`. Override them in the `Extra vars` section of `ansible/vars/all.yml`.

**Control-plane / SNO**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `controlplane_localstorage_configuration` | `false` | Master enable for control-plane local storage setup |
| `controlplane_localstorage_lvm_devices` | `[]` | List of disks to partition and include in the LVM volume group. Empty list disables LVM setup |
| `controlplane_localstorage_disk_devices` | `[]` | List of disks to wipe and expose as raw block devices to LSO |
| `controlplane_localstorage_lv_count` | `10` | Number of thin logical volumes to create in the LVM volume group |
| `controlplane_localstorage_lv_size` | `100G` | Size of each thin logical volume |

**Worker nodes**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `worker_localstorage_configuration` | `false` | Master enable for worker node local storage setup |
| `worker_localstorage_lvm_devices` | `[]` | List of disks to partition and include in the LVM volume group on worker nodes. Empty list disables LVM setup |
| `worker_localstorage_disk_devices` | `[]` | List of disks to wipe and expose as raw block devices to LSO on worker nodes |
| `worker_localstorage_lv_count` | `10` | Number of thin logical volumes to create per worker node |
| `worker_localstorage_lv_size` | `100G` | Size of each thin logical volume |

**LocalVolume volume modes**

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `localstorage_lvm_volume_mode` | `Filesystem` | `volumeMode` for the `localvolume-lvm` resource (`Filesystem` or `Block`) |
| `localstorage_disk_volume_mode` | `Block` | `volumeMode` for the `localvolume-disk` resource (`Filesystem` or `Block`) |
| `localstorage_disk_force_wipe` | `true` | Sets `forceWipeDevicesAndDestroyAllData` on the `localvolume-disk` resource, causing LSO to wipe any existing filesystem signatures on the devices |

**etcd on NVMe** (related, but separate from LSO)

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `controlplane_etcd_on_nvme` | `false` | Partition an NVMe disk at boot to host etcd and container storage |
| `controlplane_nvme_device` | `/dev/nvme0n1` | NVMe device to partition for etcd |

## Disk types

### LVM disks

Disks listed in `controlplane_localstorage_lvm_devices` (or `worker_localstorage_device` for workers) are handled at node boot via an Ignition-embedded script:

1. Each disk is wiped and receives a partition labeled `LS0`, `LS1`, etc.
2. All partitions are combined into a single LVM volume group `vg_ls`.
3. A thin pool `lv_tp_ls` is created using 99% of the volume group.
4. `controlplane_localstorage_lv_count` thin logical volumes (`lv_cp_tv00`, `lv_cp_tv01`, …) are carved from the pool at `controlplane_localstorage_lv_size` each.

Setting `controlplane_localstorage_lvm_devices` to an empty list disables steps 1–4; the disks are still wiped but no partitions or LVM structures are created and no LVM LocalVolume is applied.

### Plain disks

Disks listed in `controlplane_localstorage_disk_devices` are wiped at node boot (`wipeTable: true`) with no partitions created. They are exposed directly to LSO as raw block devices via the `localvolume-disk` resource.

## LocalVolume resources

Three independent `LocalVolume` resources can be created. Each is applied only when its condition is met.

| Resource | Storage class | Default mode | Condition |
| -------- | ------------- | ------------ | --------- |
| `localvolume-lvm` | `localstorage-sc` | `Filesystem` | `controlplane_localstorage_lvm_devices` or `worker_localstorage_lvm_devices` is non-empty |
| `localvolume-disk` | `localstorage-disk-sc` | `Block` | `controlplane_localstorage_disk_devices` or `worker_localstorage_disk_devices` is non-empty |

When `localstorage_lvm_volume_mode` or `localstorage_disk_volume_mode` is set to `Block`, the `fsType` field is omitted from the resource since block devices are not pre-formatted.

## Configuration examples

### Control-plane with LVM only

Three LVM logical volumes on a single disk, exposed as a filesystem storage class:

```yaml
controlplane_localstorage_configuration: true
controlplane_localstorage_lvm_devices:
  - /dev/disk/by-path/pci-0000:4a:00.0-scsi-0:0:2:0
controlplane_localstorage_lv_count: 3
controlplane_localstorage_lv_size: 500G
```

### Control-plane with LVM and disk disks

LVM volumes on one disk, plus two additional raw disks exposed as block devices:

```yaml
controlplane_localstorage_configuration: true
controlplane_localstorage_lvm_devices:
  - /dev/sdb
controlplane_localstorage_lv_count: 10
controlplane_localstorage_lv_size: 100G
controlplane_localstorage_disk_devices:
  - /dev/sdc
  - /dev/sdd
localstorage_disk_volume_mode: Block
```

This creates both `localvolume-lvm` (storage class `localstorage-sc`) and `localvolume-disk` (storage class `localstorage-disk-sc`).

### Workers with LVM

```yaml
worker_localstorage_configuration: true
worker_localstorage_device: /dev/nvme0n1
worker_localstorage_lv_count: 10
worker_localstorage_lv_size: 200G
```

### Wipe only, no LSO

To wipe disks at boot without installing LSO or creating any `LocalVolume` resources, set `controlplane_localstorage_lvm_devices` to an empty list and leave `controlplane_localstorage_disk_devices` empty:

```yaml
controlplane_localstorage_configuration: true
controlplane_localstorage_lvm_devices: []
controlplane_localstorage_disk_devices:
  - /dev/sdb
```

The disk is wiped at boot. No LSO resources are created.
