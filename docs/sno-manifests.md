To deploy a single sno hub with acm and all the rest of your baremetal nodes as a managed cluster:

Before you run create-inventory:

In all.yml add:
bm_worker_node_offset: 0
sno_node_count: 1


configure hv:
hv_inventory: true
hv_ip_offset: 25
hv_ssh_pass: password

setup hv.yml:
lab: scalelab
hv_vm_generate_manifests: true
hv_vm_manifest_type: standard

sno_cluster_count: 0
compact_cluster_count: 0
standard_cluster_count: 1
standard_cluster_node_count: 118


Deploy the SNO
Setup install ZTP/ACM

run sno-manifests playbook
ansible-playbook -i ansible/inventory/cloudXX.local ansible/sno-manifests.yml

Commit the siteconfigs and resources in /root/sno/clustername/ to the rhacm-ztp/cnf-features repo for ztp to deploy them.
