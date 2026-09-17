# Bastion Object Storage (RustFS)

RustFS is an S3-compatible object storage service that Jetlag can deploy as a podman pod on the bastion machine. It replaces the archived MinIO project as a drop-in S3-compatible alternative. RustFS is used to provide persistent object storage for workloads running on deployed clusters, such as Thanos metrics storage, Velero backup storage, and Image Based Upgrade (IBU) storage buckets.

_**Table of Contents**_

<!-- TOC -->
- [Bastion Object Storage (RustFS)](#bastion-object-storage-rustfs)
  - [Variables](#variables)
  - [Setup RustFS via setup-bastion.yml](#setup-rustfs-via-setup-bastionyml)
  - [Setup RustFS via bastion-object-store.yml](#setup-rustfs-via-bastion-object-storeyml)
  - [Accessing RustFS](#accessing-rustfs)
  - [Clean RustFS data](#clean-rustfs-data)
<!-- /TOC -->

## Variables

The following vars control the RustFS deployment and are defined in `ansible/roles/bastion-object-store/defaults/main.yml`. Override them in the `Extra vars` section of `ansible/vars/all.yml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `setup_bastion_object_store` | `false` | Enable RustFS deployment on the bastion (set in `all.yml`) |
| `object_store_path` | `/opt/jetlag/rustfs` | Base directory for RustFS storage on the bastion |
| `object_store_data_disk` | `""` | Full device path (e.g. `/dev/sdb`, `/dev/nvme0n1`, `/dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:1:0`) to partition, format as XFS, and mount at `object_store_path/data`. Empty string uses the bastion root filesystem |
| `object_store_image` | `quay.io/rustfs/rustfs` | RustFS container image |
| `object_store_image_tag` | `1.0.0-rc.6` | RustFS container image tag |
| `object_store_access_key` | `rustfs` | S3 API access key |
| `object_store_secret_key` | `rustfs123` | S3 API secret key |
| `object_store_port` | `9000` | S3 API port |
| `object_store_console_port` | `9001` | Web console port |

## Setup RustFS via setup-bastion.yml

RustFS can be deployed as part of the standard bastion setup by enabling it in `ansible/vars/all.yml` before running `setup-bastion.yml`.

Set the following in the `Extra vars` section of `ansible/vars/all.yml`:

```yaml
################################################################################
# Extra vars
################################################################################
setup_bastion_object_store: true

# Optional: use a dedicated disk for RustFS data storage
# object_store_data_disk: /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:1:0
```

Then run the bastion setup playbook:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
```

RustFS is deployed after the other bastion services and will be available at the completion of the playbook.

## Setup RustFS via bastion-object-store.yml

If the bastion is already configured and you want to deploy RustFS independently without rerunning the full `setup-bastion.yml`, use the dedicated playbook. Set `setup_bastion_object_store: true` in `ansible/vars/all.yml` as described above, then run:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-object-store.yml
```

This runs only the `bastion-object-store` role and is safe to run against an already-configured bastion without affecting other services.

## Accessing RustFS

Once deployed, RustFS exposes two endpoints on the bastion:

| Endpoint | Port | Description |
| -------- | ---- | ----------- |
| S3 API | 9000 | Used by workloads to read and write objects |
| Web console | 9001 | Browser-based management UI |

Access the web console at `http://<bastion>:9001` and log in with `object_store_access_key` and `object_store_secret_key` (defaults: `rustfs` / `rustfs123`).

The following buckets are created automatically on first start:

| Bucket | Purpose |
| ------ | ------- |
| `thanos` | Thanos metrics long-term storage |
| `dr4hub/velero` | Velero backup storage |
| `vm00001-ibu` through `vm04000-ibu` | Image Based Upgrade storage per SNO |

## Clean RustFS data

When redeploying clusters you may need to clear all data stored in RustFS to start with empty buckets. Use the dedicated clean playbook:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-object-store-clean.yml
```

This stops the RustFS pod, removes all data under `object_store_path/data`, and restarts the pod. The buckets are recreated automatically on startup. The RustFS service itself (pod, container image, configuration) is not removed — only the stored data is wiped.
