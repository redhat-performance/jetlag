# Scale Out a Single-Node Openshift Deployment

A JetLag deployed Single-Node Openshift deployment can be scaled out via JetLag. Workers can be added using JetLag Inventory and Playbooks. This guide assumes you have an existing Single-Node OCP cluster deployed via JetLag. The worker section in the JetLag inventory file should contain records that represent the worker nodes currently joined to the running cluster.

_**Steps to Scale Out:**_
- [Add New Node Entries to Worker Inventory](#add-new-node-entries-to-worker-inventory)
- [Update scale_out.yml](#update-scale_out.yml)
- [Run mno-scale-out.yml](#run-mno-scale-out.yml)

## Add Nodes to Worker Inventory

To add new node entries to the worker inventory there are two potential options.

1. New bare metal nodes are to be added to SNO Cluster

   If more nodes were added to SNO Cluster, update worker_node_count in the ansible/vars/all.yml file and rerun the create-inventory playbook. Be sure to compare the previous inventory file to the new one to ensure that everything is the same except the new nodes added to the worker section. Make sure to populate the extra vars related to Worker nodes.

2. Manual entry

   You can add new entries to the worker inventory section manually. Place them at the end of the list of worker entries.

   The new bare metal nodes, must be placed at the end of the worker nodes inventory. The scale out playbook is designed to use the last n nodes in the inventory.

   Populate the worker node vars([worker:vars]) same as SNO node vars ([sno:vars]) and update the role parameter as worker in [worker:vars].

## Update scale_out.yml
There are two variables in ansible/vars/scale_out.yml that indicate which entries from the worker inventory section should be added to the existing cluster.

- current_worker_count: This value indicates the number of entries in the worker inventory section to skip before starting to add nodes to the existing cluster. This number should match the current number of worker nodes associated with the existing cluster.
- scale_out_count: This value indicates the number of entries in the worker inventory section that will be added as new workers to the existing cluster.

Example: If the initial OCP deployment had three baremetal workers and the intended worker count was ten, current_worker_count would be 3 and scale_out_count would be 7. Scale out from three existing workers, adding seven new workers, for a total of ten worker nodes.

## Run mno-scale-out.yml
Once the new worker records are added and Worker node variables are properly populated in the inventory and the scale_out.yml file has the proper values. The final step is to run the mno-scale-out.yml playbook.

```console
(.ansible) [root@xxx-h01-000-r650 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-scale-out.yml
...
```

This playbook will:
- Generate node configuration yml
- Invoke `oc adm node-image create` with the node configuration, which generates a discovery ISO
- Boot the new worker nodes off of the generated discovery ISO
- Approve generated CSRs

This workflow can be run repeatedly to add more workers to the existing cluster.