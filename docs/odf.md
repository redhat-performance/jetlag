# OpenShift Data Foundation (ODF)

Jetlag can install [OpenShift Data Foundation (ODF)](https://docs.openshift.com/container-platform/latest/storage/persistent_storage/persistent-storage-ocs.html) on MNO clusters during post-install. ODF provides Ceph-backed block, file, and object storage classes for workloads running on the deployed cluster.

_**Table of Contents**_

<!-- TOC -->
- [OpenShift Data Foundation (ODF)](#openshift-data-foundation-odf)
  - [Prerequisites](#prerequisites)
  - [Variables](#variables)
  - [Configuration example](#configuration-example)
  - [How it works](#how-it-works)
  - [Storage classes provided by ODF](#storage-classes-provided-by-odf)
  - [Disconnected registries](#disconnected-registries)
<!-- /TOC -->

## Prerequisites

ODF requires the Local Storage Operator (LSO) to provide raw block devices as PersistentVolumes. Before enabling ODF, configure LSO with **disk** devices (not LVM) so that the `localstorage-disk-sc` storage class is created. See [local-storage.md](local-storage.md) for LSO setup details.

Minimum requirements:

- **Cluster type**: MNO only (ODF is not supported on SNO deployments in Jetlag)
- **Nodes**: At least 3 nodes (control-plane or worker) with available block devices
- **Block devices**: Each node must have at least one unused disk configured via `controlplane_localstorage_disk_devices` or `worker_localstorage_disk_devices`
- **LSO**: `controlplane_localstorage_configuration: true` (or `worker_localstorage_configuration: true`) with disk devices listed
- **Node labels**: The label `cluster.ocs.openshift.io/openshift-storage=` must be applied to the nodes that will host ODF. Set this via `post_install_node_labels`

## Variables

All variables are defined in `ansible/roles/mno-post-cluster-install/defaults/main/odf.yml`. Override them in the `Extra vars` section of `ansible/vars/all.yml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `setup_odf` | `false` | Enable ODF installation during post-install |
| `odf_channel` | `stable-4.21` | ODF operator subscription channel (align with your OCP version) |
| `odf_storagecluster_device_count` | `1` | Number of storageDeviceSets. Each set consumes one block PV per replica node, so a count of 1 with 3 replicas uses 3 PVs total. Increment by 1 for each additional set of 3 block PVs |
| `odf_storagecluster_replica_count` | `3` | Number of replicas per device set (minimum 3 for production) |
| `odf_storagecluster_storage_size` | `100Gi` | Size of each PVC in the device set (minimum 100Gi, maximum 4Ti). Should not exceed the size of the underlying block device |
| `odf_storagecluster_storage_class` | `localstorage-disk-sc` | StorageClass backing the device set PVCs. Must match the storage class created by LSO for disk devices |
| `wait_for_odf_storagecluster_ready` | `false` | Wait for the StorageCluster to reach Ready status before the playbook finishes |
| `wait_for_odf_storagecluster_ready_timeout` | `20m` | Timeout for the readiness wait |

## Configuration example

This example deploys ODF on an MNO cluster using Dell r660 nodes in Scale Lab with two raw block disks per control-plane node, each approximately 1.4 TB.

Add the following to the `Extra vars` section of `ansible/vars/all.yml`:

```yaml
################################################################################
# Extra vars
################################################################################

# --- Node labels (required for ODF) ---
post_install_node_labels:
- cluster.ocs.openshift.io/openshift-storage=

# --- Local Storage (prerequisite for ODF) ---
controlplane_localstorage_configuration: true
controlplane_localstorage_disk_devices:
- /dev/disk/by-path/pci-0000:4a:00.0-scsi-0:0:2:0
- /dev/disk/by-path/pci-0000:4a:00.0-scsi-0:0:3:0

# --- ODF ---
setup_odf: true
odf_storagecluster_device_count: 2
odf_storagecluster_storage_size: 1400Gi
```

With 3 control-plane nodes each contributing 2 block devices, this creates a StorageCluster with 2 device sets x 3 replicas = 6 OSDs, for a total raw capacity of approximately 8.4 TB (6 x 1400Gi).

Optionally, configure Prometheus to use ODF-backed storage:

```yaml
apply_cluster_monitoring_config: true
prometheus_storage_class: ocs-storagecluster-cephfs
prometheus_storage_size: 100Gi
```

Then deploy the cluster as usual:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
```

ODF is installed automatically during the post-install phase of the deployment.

## How it works

When `setup_odf: true`, the `mno-post-cluster-install` role performs these steps after LSO configuration:

1. **Installs the ODF operator** - creates the `openshift-storage` namespace, an OperatorGroup, and a Subscription for `odf-operator`
2. **Creates the StorageCluster** - applies the `ocs-storagecluster` resource once the ODF operator's CRDs are available (retries for up to ~15 minutes while the operator installs)
3. **Waits for readiness** (optional) - if `wait_for_odf_storagecluster_ready: true`, waits for the StorageCluster phase to reach `Ready`

## Storage classes provided by ODF

Once the StorageCluster is ready, ODF creates the following storage classes:

| Storage class | Type | Typical use |
| ------------- | ---- | ----------- |
| `ocs-storagecluster-ceph-rbd` | Block (RWO) | Database volumes, general block storage |
| `ocs-storagecluster-cephfs` | Filesystem (RWX) | Shared filesystems, Prometheus storage |
| `ocs-storagecluster-ceph-rgw` | Object (S3) | Object storage via RADOS Gateway |
| `openshift-storage.noobaa.io` | Object (S3) | Object storage via NooBaa |

## Disconnected registries

When deploying with a bastion registry (`use_bastion_registry: true`), the ODF operator subscription automatically uses the bastion's mirrored operator catalog instead of `redhat-operators`. Ensure the ODF-related operators are included in `catalogs_to_sync`. The required packages are:

- `odf-operator`
- `ocs-operator`
- `mcg-operator`
- `odf-csi-addons-operator`
- `ocs-client-operator`
- `odf-prometheus-operator`
- `recipe`
- `rook-ceph-operator`
- `cephcsi-operator`
- `odf-dependencies`
- `odf-external-snapshotter-operator`

See the `catalogs_to_sync` section in `ansible/vars/all.sample.yml` for an example of pinning these to specific versions.
