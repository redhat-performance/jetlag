# HV Metrics role

This role can install and configure **Prometheus** and **node_exporter** to collect metrics from hypervisors hosts.

Main goal is to collect hypervisor performance and load information for better understanding of actual load during VMNO scale deployments with overcommits.

Server part is a minimal **Prometheus** configuration deployed as podman container that collects metrics from hypervisors.

Hypervisors have only **node_exporter** container running.

### Usage

Theoretically it doesnot matter how to run the role as long as correct inventory is passed. Server is configured on first Bastion node and client will be configured on all machines in hv group.

Design of the role within the jetlag framework is to be used during bastion setup as a server and during hypervisors setup as a client.

#### Playbook use
Example for `setup-bastion.yml`:

```
 name: Setup bastion machine
  hosts: bastion
  vars_files:
  - vars/lab.yml
  - vars/all.yml
  roles:
  - name: hv-metrics
    vars:
      - hv_metrics_sanity: true
      - hv_metrics_cleanup: true
      - hv_metrics_install_server: true
    when: configure_hv_metrics
    ...
```

Example for `hv-setup.yml`:
```
- name: Setup hypervisors to host VMs
  hosts: hv
  vars_files:
  - vars/lab.yml
  - vars/hv.yml
  ...
  roles:
  - name: hv-metrics
    vars:
      - hv_metrics_sanity: true
      - hv_metrics_cleanup: true
      - hv_metrics_install_client: true
    when: configure_hv_metrics
    ...
```

#### Ad-hoc use

Server:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=hv-metrics \
-e hv_metrics_sanity=true \
-e hv_metrics_cleanup=true \
-e hv_metrics_install_server=true
```

Client:
```
ansible -i <inventory_file> hv --module-name include_role --args name=hv-metrics \
-e hv_metrics_sanity=true \
-e hv_metrics_cleanup=true \
-e hv_metrics_install_client=true \
```


### Ad-hoc Cleanup

Bastion:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=hv-metrics -e hv-metrics_cleanup=true
```
Hypervisors:
```
ansible -i <inventory_file> hv --module-name include_role --args name=hv-metrics -e hv-metrics_cleanup=true
```

### Requirements

- Role is tested on RHEL 9 only
- podman should be available in repos