# Advanced Cluster Management (ACM) Hub Setup

This guide covers upgrading a Jetlag-deployed OpenShift cluster to serve as an Advanced Cluster Management (ACM) Hub and managing spoke clusters. Jetlag deploys the foundation cluster, and [acm-deploy-load](https://github.com/redhat-performance/acm-deploy-load) handles ACM Hub installation and spoke cluster management.

_**Table of Contents**_

<!-- TOC -->
- [Advanced Cluster Management (ACM) Hub Setup](#advanced-cluster-management-acm-hub-setup)
  - [Overview](#overview)
  - [Hub Cluster Deployment](#hub-cluster-deployment)
  - [Disabling LSO and ODF](#disabling-lso-and-odf)
  - [Generating Spoke Cluster Manifests](#generating-spoke-cluster-manifests)
  - [Deploying Spoke Clusters](#deploying-spoke-clusters)
  - [References](#references)
<!-- /TOC -->

## Overview

ACM Hub clusters deployed via Jetlag should be configured as **compact clusters** with no worker nodes. This maximizes available hardware for spoke clusters and test workloads. The Hub manages spoke clusters that can be deployed either manually via generated manifests or automatically via GOGS integration.

Key characteristics of a Jetlag ACM Hub:
- **Cluster type**: MNO (Multi Node OpenShift)
- **Worker nodes**: 0 (compact cluster configuration)
- **Bastion**: Hosts the Assisted Installer and serves as a platform for manifest generation and cluster management
- **Hypervisor nodes**: Automatically allocated from unused hardware and available for spoke cluster VMs. See [docs/hypervisors.md](hypervisors.md) for detailed setup and management procedures

## Hub Cluster Deployment

Configure your `ansible/vars/all.yml` for an ACM Hub deployment:

```yaml
# Multi Node OpenShift with zero worker nodes (compact cluster)
cluster_type: mno
worker_node_count: 0

# Disable LSO and ODF in Jetlag - will be managed by acm-deploy-load instead
setup_lso: false
setup_odf: false

# Optionally deploy MinIO if needed for test workloads if S3 object storage is needed
# setup_bastion_minio: true
```

Deploy the Hub cluster using the standard Jetlag workflow:

```console
# Create inventory
[root@<bastion> jetlag]# ansible-playbook ansible/create-inventory.yml

# Setup bastion
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml

# Deploy MNO Hub cluster
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml
```

Once the Hub cluster is deployed and stable, use acm-deploy-load to install and configure ACM. It is recommended to deactivate the Jetlag virtual environment and move out of the Jetlag directory before cloning acm-deploy-load:

```console
[root@<bastion> jetlag]# deactivate
[root@<bastion> jetlag]# cd ~
[root@<bastion> ~]# git clone https://github.com/redhat-performance/acm-deploy-load.git
[root@<bastion> ~]# cd acm-deploy-load
[root@<bastion> acm-deploy-load]# source bootstrap.sh
[root@<bastion> acm-deploy-load]# ansible-playbook -i <hub-kubeconfig-path> rhacm-deploy.yml
```

See the [acm-deploy-load](https://github.com/redhat-performance/acm-deploy-load) repository for detailed installation and configuration options.

## Disabling LSO and ODF

By default, Jetlag can deploy Local Storage Operator (LSO) and OpenShift Data Foundation (ODF) on the cluster. For ACM Hub clusters, these should be managed by acm-deploy-load instead to ensure consistent configuration across your Hub and spoke clusters.

To disable LSO and ODF during Jetlag deployment, add these variables to the `Extra vars` section of `ansible/vars/all.yml`:

```yaml
################################################################################
# Extra vars
################################################################################
setup_lso: false
setup_odf: false
```

Alternatively, if you already have an existing cluster with LSO/ODF enabled, remove them before installing ACM:

```console
# Remove ODF (if installed)
[root@<bastion> ~]# oc delete namespace openshift-storage

# Remove LSO (if installed)
[root@<bastion> ~]# oc delete namespace openshift-local-storage
```

## Generating Spoke Cluster Manifests

Once the Hub cluster is running, use acm-deploy-load to generate manifests for spoke clusters that will be managed by ACM. These manifests can then be applied manually or integrated with GOGS for automated cluster provisioning.

The acm-deploy-load playbooks derive cluster configuration from the inventory file. First, copy the hypervisor inventory groups from your Jetlag inventory to the acm-deploy-load inventory:

```console
[root@<bastion> acm-deploy-load]# sed -n '/\[hv/,$p' ../jetlag/ansible/inventory/cloud49.local >> ansible/inventory/cloud49.local
```

To generate spoke cluster manifests, copy and customize the `telco-core.sample.yml` vars file, then run the `telco-core-manifests` playbook:

```console
[root@<bastion> acm-deploy-load]# cp ansible/vars/telco-core.sample.yml ansible/vars/telco-core.yml
[root@<bastion> acm-deploy-load]# vi ansible/vars/telco-core.yml
[root@<bastion> acm-deploy-load]# ansible-playbook -i ansible/inventory/cloud49.local ansible/telco-core-manifests.yml
```

Refer to the [acm-deploy-load](https://github.com/redhat-performance/acm-deploy-load) repository for complete details on vars configuration and manifest generation options.

## Deploying Spoke Clusters

### Manual Spoke Deployment

Once manifests are generated, apply them from the bastion using the `oc` CLI to create the spoke cluster resources in the Hub:

<TBD>

### Automated Spoke Deployment via GOGS

For larger deployments or continuous provisioning, integrate with GOGS (Git server) to automatically manage spoke cluster manifests:

<TBD>

## References

- **[acm-deploy-load](https://github.com/redhat-performance/acm-deploy-load)**: ACM Hub installation and spoke management toolkit
- **[CLAUDE.md](../CLAUDE.md)**: Jetlag cluster deployment workflows
- **[docs/troubleshooting.md](troubleshooting.md)**: Jetlag troubleshooting and bastion recovery
- **[docs/bastion-minio.md](bastion-minio.md)**: MinIO object storage for spoke cluster workloads
- **[Advanced Cluster Management Documentation](https://access.redhat.com/documentation/en-us/red_hat_advanced_cluster_management_for_kubernetes/)**: Official ACM documentation
