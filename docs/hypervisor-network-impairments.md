## Hypervisor Network-Impairments

BM/RWN cluster types will allocate remaining hardware that was not put in the inventory for the cluster as Hypervisor nodes. For testing where network impairments are required, we can apply latency/packet-loss/bandwidth impairments on the hypervisor nodes. The `create-inventory.yml` playbook automatically selects scale lab "network 1" nic names for the host var `impaired_nic` in the hypervisor inventory. To change this, adjust `hypervisor_nic_interface_idx` as an extra var applied to the `all.yml` vars file.

To apply network impairments, first copy the network-impairments sample vars file

```console
cp ansible/vars/network-impairments.sample.yml ansible/vars/network-impairments.yml
vi ansible/vars/network-impairments.yml
```

Make sure to set/review the following vars:

* `install_tc` - toggles installing traffic control
* `apply_egress_impairments` and `apply_ingress_impairments` - toggles out-going or incoming traffic impairments
* `egress_delay` and `ingress_delay` - latency for egress/ingress in milliseconds
* `egress_packet_loss` and `ingress_packet_loss` - packet loss in percent (Example `0.01` for 0.01%)
* `egress_bandwidth` and `ingress_bandwidth` - bandwidth in kilobits (Example `100000` which is 100000kbps or 100Mbps)

Apply impairments:

```console
ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml
```

Remove impairments:

```console
ansible-playbook -i ansible/inventory/cloud03.local ansible/hv-network-impairments.yml -e 'apply_egress_impairments=false apply_ingress_impairments=false'
```

Note, egress impairments are applied directly to the impaired nic. Ingress impairments are applied to an ifb interface that handles ingress traffic for the impaired nic.
