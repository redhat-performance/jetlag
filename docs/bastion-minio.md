# Bastion MinIO

MinIO is an S3-compatible object storage service that Jetlag can deploy as a podman pod on the bastion machine. It is used to provide persistent object storage for workloads running on deployed clusters, such as Thanos metrics storage, Velero backup storage, and Image Based Upgrade (IBU) storage buckets.

_**Table of Contents**_

<!-- TOC -->
- [Bastion MinIO](#bastion-minio)
  - [Variables](#variables)
  - [Setup MinIO via setup-bastion.yml](#setup-minio-via-setup-bastionyml)
  - [Setup MinIO via bastion-minio.yml](#setup-minio-via-bastion-minioyml)
  - [Accessing MinIO](#accessing-minio)
  - [Clean MinIO data](#clean-minio-data)
<!-- /TOC -->

## Variables

The following vars control the MinIO deployment and are defined in `ansible/roles/bastion-minio/defaults/main.yml`. Override them in the `Extra vars` section of `ansible/vars/all.yml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `setup_bastion_minio` | `false` | Enable MinIO deployment on the bastion (set in `all.yml`) |
| `minio_store_path` | `/opt/minio` | Base directory for MinIO storage on the bastion |
| `minio_data_disk` | `""` | Full device path (e.g. `/dev/sdb`, `/dev/nvme0n1`, `/dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:1:0`) to partition, format as XFS, and mount at `minio_store_path/data`. Empty string uses the bastion root filesystem |
| `minio_image` | `quay.io/minio/minio` | MinIO container image |
| `minio_image_tag` | `RELEASE.2025-09-07T16-13-09Z` | MinIO container image tag |
| `minio_access_key` | `minio` | MinIO S3 API access key |
| `minio_secret_key` | `minio123` | MinIO S3 API secret key |
| `minio_port` | `9000` | MinIO S3 API port |
| `minio_console_port` | `9001` | MinIO web console port |

## Setup MinIO via setup-bastion.yml

MinIO can be deployed as part of the standard bastion setup by enabling it in `ansible/vars/all.yml` before running `setup-bastion.yml`.

Set the following in the `Extra vars` section of `ansible/vars/all.yml`:

```yaml
################################################################################
# Extra vars
################################################################################
setup_bastion_minio: true

# Optional: use a dedicated disk for MinIO data storage
# minio_data_disk: /dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:1:0
```

Then run the bastion setup playbook:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
```

MinIO is deployed after the other bastion services and will be available at the completion of the playbook.

## Setup MinIO via bastion-minio.yml

If the bastion is already configured and you want to deploy MinIO independently without rerunning the full `setup-bastion.yml`, use the dedicated playbook. Set `setup_bastion_minio: true` in `ansible/vars/all.yml` as described above, then run:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-minio.yml
```

This runs only the `bastion-minio` role and is safe to run against an already-configured bastion without affecting other services.

## Accessing MinIO

Once deployed, MinIO exposes two endpoints on the bastion:

| Endpoint | Port | Description |
| -------- | ---- | ----------- |
| S3 API | 9000 | Used by workloads to read and write objects |
| Web console | 9001 | Browser-based management UI |

Access the web console at `http://<bastion>:9001` and log in with `minio_access_key` and `minio_secret_key` (defaults: `minio` / `minio123`).

The following buckets are created automatically on first start:

| Bucket | Purpose |
| ------ | ------- |
| `thanos` | Thanos metrics long-term storage |
| `dr4hub/velero` | Velero backup storage |
| `vm00001-ibu` through `vm04000-ibu` | Image Based Upgrade storage per SNO |

## Clean MinIO data

When redeploying clusters you may need to clear all data stored in MinIO to start with empty buckets. Use the dedicated clean playbook:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-minio-clean.yml
```

This stops the MinIO pod, removes all data under `minio_store_path/data`, and restarts the pod. The buckets are recreated automatically on startup. The MinIO service itself (pod, container image, configuration) is not removed — only the stored data is wiped.
