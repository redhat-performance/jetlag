# Performance Co-Pilot (PCP) role

This role can install and configure the Performance Co-Pilot or PCP (https://pcp.readthedocs.io/en/latest/index.html) in a Centralized logging - pmlogger farm configuration:

![pmlogger farm](https://access.redhat.com/webassets/avalon/d/Red_Hat_Enterprise_Linux-8-Monitoring_and_managing_system_status_and_performance-en-US/images/6a30238925dab26408092ae39258801e/173_RHEL_instaling_PCP_0721_centralized.png)

Main goal is to collect hypervisor performance and load information for better understanding of actual load vs the sum of VM perspectives.

Server task can be used with `pcp_server_configure_clients: false` to be used as a local instance of pcp.

> Do not use client task (`pcp_install_client: true`) for that purpose, it's exposing pcp to the network on port `44321/tcp`.

### Usage

By defaut role is configured via control flow variable to noop, you need to explicitly enable desired steps.

Design of the role within the jetlag framework is to be used for bastion setup as a server and hypervisors as a client.

#### Playbook use
Example for setup-bastion.yml:

```
 name: Setup bastion machine
  hosts: bastion
  vars_files:
  - vars/lab.yml
  - vars/all.yml
  roles:
  - name: pcp
    vars:
      - pcp_sanity: true
      - pcp_cleanup: true
      - pcp_install_server: true
    when: configure_pcp_server
    ...
```

Example for hv-setup.yml:
```
- name: Setup hypervisors to host VMs
  hosts: hv
  vars_files:
  - vars/lab.yml
  - vars/hv.yml
  ...
  roles:
  - name: pcp
    vars:
      - pcp_sanity: true
      - pcp_cleanup: true
      - pcp_install_client: true
      - pcp_listen_interface_name: "{{ hv_lab_interface }}"
    when: configure_pcp_client
    ...
```

#### Ad-hoc use

Server:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=pcp \
-e pcp_sanity=true \
-e pcp_cleanup=true \
-e pcp_install_server=true
```

Client:
```
ansible -i <inventory_file> bastion --module-name include_role --args name=pcp \
-e pcp_sanity=true \
-e pcp_cleanup=true \
-e pcp_install_client=true \
-e pcp_listen_interface_name=eno3
```
> Adjust `pcp_listen_interface name` accordingly to the lab interface

### Ad-hoc Cleanup

```
ansible -i <inventory_file> bastion --module-name include_role --args name=pcp -e pcp_cleanup=true
```

### Requirements

Role is tested on RHEL 9 only