# Deploy Multi-Node OpenShift Hybrid Deployment in ScaleLab

1. Configure `all.yml` like a standard scalelab allocation. Add the following variables:
```
cluster_type: mno           # This is important to distinguish from the 'vmno' type deployment, which does not permit any nodes to be bare metal.
hv_inventory: true
hv_ssh_pass: 200metersq+
hybrid_worker_count: 500
```
This is to verify the inventory looks good. However, we want to run the install in two steps. The reasoning behind this is to separate any issues that could happen from the initial install from the scale up to 500 workers. Each task has its own set of moving pieces and it is nicer to debug an install on a smaller cluster than also trying to troubleshoot massive node creations at the same time. 

Step 1: Install small cluster 3x CP + 3x worker
1. set: `hybrid_worker_count: 0`
2. Run create-inventory
3. Run deploy-mno
4. Run `setup-hypervisor` 

Step 2: Scale up to 500 workers.
1. set `hybrid_worker_count: 500`
2. run create-inventory
3. 