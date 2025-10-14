# Scale Out a Single-Node Openshift Deployment

A JetLag deployed Single-Node Openshift deployment can be scaled out via JetLag. Workers can be added using JetLag Inventory and Playbooks. This guide assumes you have an existing Single-Node OCP cluster deployed via JetLag. The worker section in the JetLag inventory file should contain records that represent the worker nodes that will be joined to the running cluster.

## Addtional step in case of Multi SNO Environments

⚠️ A potential risk exists wherein a user who deploys a second Single Node OpenShift (SNO) instance could accidentally overwrite it if they later attempt to expand the first SNO with a worker node.

⚠️ In Multi SNO Environment, You can create a new json file with the bastion host and desired hosts in a order where Bastion node follows other desired hosts for each SNO Cluster. See [tips and vars](tips-and-vars.md#override-lab-ocpinventory-json-file) for more information how to override lab ocpinventory json file.

Once the inventory files are properly prepared,follow SNO deploy and SNO scale out steps for each SNO Cluster.

_**Steps to Scale Out:**_
- [Add New Node Entries to Worker Inventory](#add-new-node-entries-to-worker-inventory)
- [Update scale_out.yml](#update-scale_out.yml)
- [Run ocp-scale-out.yml](#run-ocp-scale-out.yml)

## Add New Node Entries to Worker Inventory

There are two methods for adding new worker node entries to the inventory. Choose one based on your workflow:

### Option 1: Regenerate Inventory via Ansible (Recommended for SNO Additions)

Use this method if you're adding new bare metal nodes to a **Single Node OpenShift (SNO)** cluster.

1. Update the `worker_node_count` value in `ansible/vars/all.yml` to reflect the new total number of worker nodes.
2. **Optional:** Set `worker_install_disk` extra vars parameter in `ansible/vars/all.yml` if your hardware is not in the automatic `hw_install_disk` mappings (see `ansible/vars/lab.yml`) or if you need to override the default.
3. Rerun the `create-inventory` playbook.
4. After generation, compare the updated inventory file with the previous version to ensure only the new nodes were added to the `[worker]` section.
5. Ensure all required worker-related variables are set in `[worker:vars]`.

### Option 2: Manual Inventory Update

Use this method to manually add new nodes without rerunning the playbook.

1. Append the new worker nodes to the **end** of the `[worker]` section in the inventory.
   - ⚠️ The **scale-out playbook** uses the **last `n` nodes** in the list, so order matters.
2. In the `[worker:vars]` section:
   - Populate the required variables just as you would in `[sno:vars]`.
   - Set the `role` parameter to `worker`.
Here is an example:

   ```ini
   [worker]
   e29-xxx-xxxx-r640 bmc_address=**REDACTED** mac_address=**REDACTED**       lab_mac=**REDACTED** ip=**REDACTED** vendor=Dell install_disk=/dev/disk/by-path/pci-0000:18:00.0-scsi-0:2:0:0

   [worker:vars]
   role=worker
   bmc_user=**REDACTED**
   bmc_password=**REDACTED**
   lab_interface=**REDACTED**
   network_interface=**REDACTED**
   network_prefix=**REDACTED**
   gateway=**REDACTED**
   dns1=**REDACTED**
   ```



## Update scale_out.yml
There are two variables in ansible/vars/scale_out.yml that indicate which entries from the worker inventory section should be added to the existing cluster.

- current_worker_count: This value indicates the number of entries in the worker inventory section to skip before starting to add nodes to the existing cluster. This number should match the current number of worker nodes associated with the existing cluster.
- scale_out_count: This value indicates the number of entries in the worker inventory section that will be added as new workers to the existing cluster.

Example: If the initial OCP deployment had three baremetal workers and the intended worker count was ten, current_worker_count would be 3 and scale_out_count would be 7. Scale out from three existing workers, adding seven new workers, for a total of ten worker nodes.

   ```yaml
   current_worker_count: 3
   scale_out_count: 7
   ```

## Run mno-scale-out.yml
Once the new worker records are added and Worker node variables are properly populated in the inventory and the scale_out.yml file has the proper values. The final step is to run the mno-scale-out.yml playbook.

```console
(.ansible) [root@xxx-h01-000-r650 jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/ocp-scale-out.yml
...
```

This playbook will:
- Generate node configuration yml
- Invoke `oc adm node-image create` with the node configuration, which generates a discovery ISO
- Boot the new worker nodes off of the generated discovery ISO
- Approve generated CSRs

This workflow can be run repeatedly to add more workers to the existing cluster. A typical scale-out will require around 30-40 minutes to complete mostly depending upon how fast your systems reboot. It is suggested to monitor your deployment to see if anything hangs on boot or if the virtual media is incorrect according to the bmc.