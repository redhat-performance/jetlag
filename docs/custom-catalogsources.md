# Custom CatalogSources and Per-Operator Overrides

Jetlag supports applying custom [CatalogSource](https://docs.openshift.com/container-platform/latest/operators/understanding/olm-understanding-operatorhub.html) resources to the cluster post-install and overriding the catalog source used by each operator's Subscription. This allows operators to be installed from custom or third-party operator indexes instead of the default `redhat-operators` catalog.

_**Table of Contents**_

<!-- TOC -->
- [Custom CatalogSources and Per-Operator Overrides](#custom-catalogsources-and-per-operator-overrides)
  - [Use cases](#use-cases)
  - [Custom CatalogSources](#custom-catalogsources)
    - [Variables](#variables)
    - [Configuration example](#configuration-example)
  - [Per-operator CatalogSource overrides](#per-operator-catalogsource-overrides)
    - [Override variables](#override-variables)
    - [Precedence](#precedence)
  - [Full example: ODF from a custom catalog](#full-example-odf-from-a-custom-catalog)
  - [Multiple custom catalogs](#multiple-custom-catalogs)
<!-- /TOC -->

## Use cases

- Install pre-release or development builds of operators from a custom index image
- Use a third-party operator catalog alongside the default Red Hat catalog
- Test specific operator versions that are not yet available in the default catalog
- Install different operators from different custom catalogs

## Custom CatalogSources

The `custom_catalogsources` variable defines CatalogSource resources that are applied to the `openshift-marketplace` namespace during post-install. Each entry creates a separate CatalogSource that operators can subscribe to.

### Variables

Add these to the `Extra vars` section of `ansible/vars/all.yml` (or `ansible/vars/ibmcloud.yml`).

| Variable | Type | Description |
| -------- | ---- | ----------- |
| `custom_catalogsources` | list | List of CatalogSource definitions to apply (default: `[]`) |
| `custom_catalogsources[].name` | string | Name of the CatalogSource resource |
| `custom_catalogsources[].image` | string | Index image reference (e.g., `quay.io/org/index:tag`) |
| `custom_catalogsources[].displayName` | string | Display name shown in OperatorHub (default: value of `name`) |
| `custom_catalogsources[].publisher` | string | Publisher name (default: `Custom`) |

### Configuration example

```yaml
################################################################################
# Extra vars
################################################################################

custom_catalogsources:
- name: my-custom-catalog
  image: quay.io/my-org/my-operator-index:v4.21
  displayName: My Custom Catalog
  publisher: My Org
```

This creates the following CatalogSource in the cluster:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: my-custom-catalog
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/my-org/my-operator-index:v4.21
  displayName: My Custom Catalog
  publisher: My Org
```

## Per-operator CatalogSource overrides

Each post-install operator can be pointed to a specific CatalogSource by setting a per-operator override variable. When set, the override takes precedence over all other catalog source selection logic.

### Override variables

| Variable | Default | Operator | Applies to |
| -------- | ------- | -------- | ---------- |
| `odf_catalogsource` | `redhat-operators` | OpenShift Data Foundation | MNO |
| `lso_catalogsource` | `redhat-operators` | Local Storage Operator | MNO, SNO |
| `gitops_catalogsource` | `redhat-operators` | OpenShift GitOps | MNO, SNO |
| `aap_catalogsource` | `redhat-operators` | Ansible Automation Platform | MNO |

All variables default to `redhat-operators`. When left at the default, the existing behavior is preserved (bastion registry catalog if `use_bastion_registry: true`, otherwise `redhat-operators`). Setting a variable to any other value overrides both the bastion registry catalog and the default.

### Precedence

The catalog source for each operator Subscription is determined in this order:

1. **Per-operator override** (e.g., `odf_catalogsource`) - highest priority
2. **Bastion registry catalog** (`generated_operator_index_name_tag`) - when `use_bastion_registry: true`
3. **Default** (`redhat-operators`) - fallback

## Full example: ODF from a custom catalog

This example installs ODF from a custom operator index while leaving LSO on the default `redhat-operators` catalog.

```yaml
################################################################################
# Extra vars
################################################################################

# Define the custom CatalogSource
custom_catalogsources:
- name: odf-testing-catalog
  image: quay.io/my-org/odf-operator-index:v4.21-rc1
  displayName: ODF Testing Catalog
  publisher: My Org

# Point only ODF at the custom catalog
odf_catalogsource: odf-testing-catalog
odf_channel: stable-4.21

# LSO uses the default redhat-operators (no override set)
controlplane_localstorage_configuration: true
controlplane_localstorage_disk_devices:
- /dev/disk/by-path/pci-0000:4a:00.0-scsi-0:0:2:0

# Enable ODF
setup_odf: true

post_install_node_labels:
- cluster.ocs.openshift.io/openshift-storage=
```

## Multiple custom catalogs

You can define multiple CatalogSources and point different operators to different catalogs:

```yaml
custom_catalogsources:
- name: odf-staging
  image: quay.io/my-org/odf-index:v4.21-staging
  displayName: ODF Staging
  publisher: My Org
- name: gitops-nightly
  image: quay.io/my-org/gitops-index:nightly
  displayName: GitOps Nightly
  publisher: My Org

# Each operator uses a different catalog
odf_catalogsource: odf-staging
gitops_catalogsource: gitops-nightly
# LSO and AAP remain on the default redhat-operators catalog
```
