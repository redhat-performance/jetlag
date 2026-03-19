# HV Metrics Server role

This role install and configure **Prometheus** instance that scrapes **node_exporter** metrics on hypervisors. **Grafana** sidecar optionally (on by default) installed.

Main goal is to collect hypervisor performance and load information for better understanding of actual load during VMNO scale deployments with overcommits.

Server part is a minimal **Prometheus** configuration deployed as podman container that collects metrics from hypervisors.

Hypervisors have only **node_exporter** container running and are configured with `hv-metrics-exporter` role.

**Grafana** is installed with a basic dashboard (`hv-metrics-server/files/dashboards/hv-metrics-dashboard.json`) by default.

At the end of the server installation with default settings, you will get an endpoint `http://<bastion_fqdn>:3000`, this will be grafana by default with `testadmin`/`testadmin` user/password and prometheus endpoint on port `9090`.

Role deploys a Podman **kube** quadlet (`*.kube` + Pod YAML under `/etc/containers/systemd`) running `prometheus` and optionally `grafana` in one pod, with config and data on the bastion under `hv_metrics_server_work_dir`.

### Configuration

You can override additional parameters by following methods:
  - Include them into your all.yml and hv.yml to be used for the deployment
  - Provide override in `vars` list section for the role
  - Pass them with `-e <hv_metrics_server_var>=<value>` for ad-hoc commands.
  
See examples below.

### Usage

Role is designed to be run as a part of `setup-bastion.yml` playbook.

In order to use role in your deployment you need to flip variable `setup_hv_metrics` in `all.yml` to true (it's already present in sample files in a `false` state). `hv_metrics_server_deploy_grafana` is used to enable or disable grafana deployment.

#### Playbook use
Example for `setup-bastion.yml`:

```
 name: Setup bastion machine
  hosts: bastion
  vars_files:
  - vars/lab.yml
  - vars/all.yml
  roles:
  - name: hv-metrics-server
    when: setup_hv_metrics
    ...
```

#### Ad-hoc use

You can execute following ad-hoc command from `../jetlag/ansible` directory:
> Do note, that this will not have a pretty output, but you only need to be concerned of the final state Changed (Success) or Fatal (Failed) or exit code.

```
ansible -i <inventory_file> bastion --module-name include_role --args name=hv-metrics-server
```

### Requirements

- Role is tested on RHEL 9 only
- podman should be installed on a bastion node
