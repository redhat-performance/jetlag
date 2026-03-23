# HV Metrics Exporter role

This role installs **node_exporter** container to collect metrics from hypervisors hosts.

This is required by `hv-metrics-server`. Container deployed with no tweaks. You can override the image used and container name via the `main.yaml` in `vars` directory.

Each node will expose metrics as html page on port `9100`.

### Usage

This role is designed to be run as a part of `hv-setup.yml` playbook.

In order to use role in your deployment you need to flip variable `setup_hv_metrics` in `hv.yml` to true (it's already present in sample files in a `false` state)

#### Playbook use

Example for `hv-setup.yml`:
```
- name: Setup hypervisors to host VMs
  hosts: hv
  vars_files:
  - vars/lab.yml
  - vars/hv.yml
  ...
  roles:
  - name: hv-metrics-exporter
    when: setup_hv_metrics
    ...
```

#### Ad-hoc use

You can execute following ad-hoc command from `../jetlag/ansible` directory:
> Do note, that this will not have a pretty output, but you only need to be concerned of the final state Changed (Success) or Fatal (Failed) or exit code.

> Make sure desired hypervisors are located in [hv] group of the inventory!

```
ansible -i <inventory_file> hv --module-name include_role --args name=hv-metrics-exporter
```

### Requirements

- Role is tested on RHEL 9 only
- podman should be installed
