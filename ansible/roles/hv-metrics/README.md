# HV Metrics role

This role install and configure **Prometheus** and **node_exporter** to collect metrics from hypervisors hosts. **Grafana** sidecar optionally (on by default) installed.

Main goal is to collect hypervisor performance and load information for better understanding of actual load during VMNO scale deployments with overcommits.

Server part is a minimal **Prometheus** configuration deployed as podman container that collects metrics from hypervisors.

Hypervisors have only **node_exporter** container running.

**Grafana** is installed with a basic dashboard (`hv-metrics/files/hv-metrics-dashboard.json`) by default.

At the end of the server installation with default settings, you will get an endpoint `http://<bastion_fqdn>:10999`, this will be grafana by default with `testadmin`/`testadmin` user/password, or prometheus endpoint if grafana is not deployed.

You can use `hv_metrics_debug: true` in case you want grafana and prometheus exposed additionally on respective ports 3000/9090 on bastion.

### Configuration

You can override additional parameters by following methods:
  - Include them into your all.yml and hv.yml to be used for the deployment
  - Provide override in `vars` list section for the role
  - Pass them with `-e <hv_metrics_var>=<value>` for ad-hoc commands.
  
See examples below.

### Usage

Theoretically it doesnot matter how to run the role as long as correct inventory is passed. Server is configured on first Bastion node and client will be configured on all machines in hv group.

Design of the role within the jetlag framework is to be used during bastion setup as a server and during hypervisors setup as a client.

In order to use role in your deployment you need to flip variable `configure_hv_metrics` in both `all.yaml` and `hv.yaml` to true (it's already present in a sample files in an `false` state)

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
      - hv_metrics_grafana_sidecar: true
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

You can execute following ad-hoc command from `../jetlag/ansible` directory:
> Do note, that this will not have a pretty output, but you only need to be concerned of the final state Changed (Success) or Fatal (Failed) or exit code.

Install Server:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=hv-metrics \
-e hv_metrics_sanity=true \
-e hv_metrics_cleanup=true \
-e hv_metrics_install_server=true \
-e hv_metrics_grafana_sidecar=true
```

Install Client:
```
ansible -i <inventory_file> hv --module-name include_role --args name=hv-metrics \
-e hv_metrics_sanity=true \
-e hv_metrics_cleanup=true \
-e hv_metrics_install_client=true
```


### Ad-hoc Cleanup

Bastion:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=hv-metrics -e hv_metrics_cleanup=true
```
Hypervisors:
```
ansible -i <inventory_file> hv --module-name include_role --args name=hv-metrics -e hv_metrics_cleanup=true
```

### Requirements

- Role is tested on RHEL 9 only
- podman should be available in repos