# Jetlag Tips and additional Vars

_**Table of Contents**_

<!-- TOC -->
- [Override lab ocpinventory json file](#override-lab-ocpinventory-json-file)
- [Post Deployment - Network Attachment Definition](#post-deployment---network-attachment-definition)
<!-- /TOC -->

## Override lab ocpinventory json file

Current jetlag lab use selects machines for roles bastion, control-plane, and worker in that order from the ocpinventory.json file. You may have to create a new json file with the desired order to match desired roles if the auto selection is incorrect. After creating a new json file, host this where your machine running the playbooks can reach and set the following var such that the modified ocpinventory json file is used:

```yaml
ocp_inventory_override: http://example.redhat.com/cloud12-inventories/cloud12-cp_r640-w_5039ms.json
```

## Post Deployment - Network Attachment Definition

Append these vars to the "Extra vars" section of your `all.yml` or `ibmcloud.yml` to add a Macvlan Network Attachment
Definition. This allows you to add an additional network to pods created in your cluster.

```yaml
setup_network_attachment_definition: true
net_attach_def_namespace: default
net_attach_def_name: net1
net_attach_def_interface: bond0
net_attach_def_range: 192.168.0.0/16
```

Modify `net_attach_def_interface` to the desired host interface in which you want the macvlan network to exist. Modify
`net_attach_def_range` to an ip range that does not conflict with any other test-bed address ranges.

To have a pod attach an interface to the additional network, add the following example metadata annotation:

```yaml
annotations:
  k8s.v1.cni.cncf.io/networks: '[{"name": "net1", "namespace": "default"}]'
```
