#!/usr/bin/env python3
"""Generate [hv_vm] inventory records from [hv] hosts, cluster, and VM definitions."""

import argparse
import ipaddress
import json
import re
import shlex
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

try:
    import yaml
except ImportError:
    yaml = None

DEFAULT_VM_TYPES = {
    "worker": {
        "per_hv": 3,
        "cpus": 8,
        "memory": 18,
        "disk_size": 120,
        "bw_avg": 11500,
        "bw_peak": 12500,
        "bw_burst": 11750,
        "disk_location": "/var/lib/libvirt/images",
    },
    "master": {
        "per_hv": 1,
        "cpus": 16,
        "memory": 64,
        "disk_size": 500,
        "bw_avg": 25000,
        "bw_peak": 30000,
        "bw_burst": 28000,
        "disk_location": "/var/lib/libvirt/images",
    }
}

DEFAULT_CLUSTER_TYPES = {
    "mno": {
        "count": 1,
        "vms": {
            "master": 3,
            "worker": 5
        }
    },
    "sno": {
        "count": 1,
        "vms": {
            "master": 1
        }
    }
}

MAC_INT_BASE = 90520730730496  # 52:54:00:00:00:00 — QEMU/KVM prefix used by Jetlag
ANSIBLE_UUID_NAMESPACE = uuid.UUID("361E6D51-FAEC-444A-9079-341386DA8E2E")

SECTION_RE = re.compile(r"^\[([^\]]+)\]$")
VAR_RE = re.compile(r"^([^=\s#]+)=(.+)$")


def is_json_topology(path):
    """Return True when the file should be loaded as a JSON topology."""
    return path.suffix == ".json" or path.stem.endswith(".json")


def topology_from_mapping(data, path):
    """Extract vm_types and cluster_types from a loaded mapping."""
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object")

    vm_types = data.get("vm_types", data.get("VM_TYPES", {}))
    cluster_types = data.get("cluster_types", data.get("CLUSTER_TYPES", {}))
    if not vm_types:
        raise ValueError(f"{path} must define 'vm_types'")
    return vm_types, cluster_types


def load_config(path):
    """Load vm_types and cluster_types from a topology config file."""
    path = Path(path)
    if not path.is_file():
        raise FileNotFoundError(f"Config file not found: {path}")

    if is_json_topology(path):
        data = json.loads(path.read_text())
        return topology_from_mapping(data, path)

    if path.suffix in {".py", ""}:
        namespace = {}
        exec(path.read_text(), namespace)  # noqa: S102
        if "VM_TYPES" not in namespace:
            raise ValueError(f"{path} must define VM_TYPES")
        cluster_types = namespace.get("CLUSTER_TYPES", {})
        return namespace["VM_TYPES"], cluster_types

    if path.suffix in {".yml", ".yaml"}:
        if yaml is None:
            raise RuntimeError("PyYAML is required to load YAML config files")
        data = yaml.safe_load(path.read_text())
        return topology_from_mapping(data, path)

    raise ValueError(f"Unsupported config file format: {path}")


def misc_fields_suffix(misc):
    """Format optional misc fields for appending to an inventory record."""
    if not misc:
        return ""
    if not isinstance(misc, dict):
        raise ValueError("misc must be an object mapping field names to values")
    return "".join(f" {key}={value}" for key, value in misc.items())


def validate_vm_types(vm_types):
    """Ensure VM type templates define per_hv and hardware fields."""
    for name, template in vm_types.items():
        if name != "sno" and "per_hv" not in template:
            raise ValueError(f"VM type '{name}' must define 'per_hv'")
        misc = template.get("misc")
        if misc is not None and not isinstance(misc, dict):
            raise ValueError(f"VM type '{name}' misc must be an object")


def validate_cluster_types(cluster_types, vm_types):
    """Ensure cluster definitions reference known VM types."""
    for name, cluster in cluster_types.items():
        if "count" not in cluster:
            raise ValueError(f"Cluster type '{name}' must define 'count'")
        vms = cluster.get("vms")
        if not vms:
            raise ValueError(f"Cluster type '{name}' must define 'vms'")
        for vm_type in vms:
            if vm_type not in vm_types:
                raise ValueError(
                    f"Cluster type '{name}' references unknown VM type '{vm_type}'"
                )


def aggregate_vm_counts(cluster_types, selected_cluster_types):
    """Sum total VMs per type across all selected cluster types."""
    totals = {}
    for cluster_name in selected_cluster_types:
        if cluster_name not in cluster_types:
            raise ValueError(f"Unknown cluster type: {cluster_name}")

        cluster = cluster_types[cluster_name]
        cluster_count = int(cluster["count"])
        if cluster_count <= 0:
            continue

        for vm_type, per_cluster_count in cluster["vms"].items():
            totals[vm_type] = totals.get(vm_type, 0) + cluster_count * int(per_cluster_count)

    return totals


def vm_types_with_counts(vm_types, vm_counts):
    """Attach aggregated counts to VM type templates for deployment planning."""
    planned = {}
    for vm_type, count in vm_counts.items():
        if count <= 0:
            continue
        planned[vm_type] = {**vm_types[vm_type], "count": count}
    return planned


VM_CLUSTER_GROUP_RE = re.compile(r"^vm_cluster_.+_\d+$")


class InventoryOutput:
    """Generated VM inventory in flat or sub-group layout."""

    def __init__(self, flat_lines=None, cluster_groups=None, children=None, sub_groups=False):
        self.flat_lines = flat_lines or []
        self.cluster_groups = cluster_groups or {}
        self.children = children or []
        self.sub_groups = sub_groups

    def all_vm_lines(self):
        if self.sub_groups:
            lines = []
            for child in self.children:
                lines.extend(self.cluster_groups.get(child, []))
            return lines
        return self.flat_lines


def inventory_uses_sub_groups(sections):
    """Return True when the inventory uses [hv_vm:children] cluster sub-groups."""
    return "hv_vm:children" in sections


def is_replaceable_vm_section(section_name):
    """Return True for VM host sections replaced by vm-planner output."""
    if section_name in {"hv_vm", "hv_vm:children"}:
        return True
    return bool(VM_CLUSTER_GROUP_RE.match(section_name))


def cluster_group_name(cluster_type, cluster_index):
    """Return the inventory sub-group name for one cluster instance."""
    return f"vm_cluster_{cluster_type}_{cluster_index - 1}"


def format_vm_inventory_blocks(inventory_output):
    """Format flat or sub-group VM inventory sections for writing or --short output."""
    blocks = []
    if inventory_output.sub_groups:
        blocks.append("[hv_vm:children]")
        blocks.extend(inventory_output.children)
        blocks.append("")
        for child in inventory_output.children:
            blocks.append(f"[{child}]")
            blocks.extend(inventory_output.cluster_groups.get(child, []))
            blocks.append("")
        if blocks and blocks[-1] == "":
            blocks.pop()
    else:
        blocks.append("[hv_vm]")
        blocks.extend(inventory_output.flat_lines)
    return blocks


def parse_inventory(path):
    """Parse an Ansible INI inventory into sections."""
    inv_path = Path(path)
    if not inv_path.is_file():
        raise FileNotFoundError(f"Inventory file not found: {inv_path}")

    sections = {}
    current = None

    for raw_line in inv_path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or line.startswith(";"):
            continue

        section_match = SECTION_RE.match(line)
        if section_match:
            current = section_match.group(1)
            sections.setdefault(current, [])
            continue

        if current is None:
            continue

        if line.startswith("#"):
            continue

        sections[current].append(raw_line.rstrip())

    return sections


def parse_section_vars(sections, section_name):
    """Parse key=value variables from an inventory section."""
    vars_ = {}
    for line in sections.get(section_name, []):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        match = VAR_RE.match(stripped)
        if match:
            vars_[match.group(1)] = match.group(2).strip().strip("'\"")
    return vars_


def parse_host_line(line):
    """Split a host line into hostname and variables."""
    tokens = line.split()
    if not tokens:
        return None, {}

    host = tokens[0]
    vars_ = {}
    for token in tokens[1:]:
        if token.startswith("#"):
            break
        match = VAR_RE.match(token)
        if match:
            vars_[match.group(1)] = match.group(2)
    return host, vars_


def parse_hv_hosts(sections):
    """Return hypervisor host records from the [hv] section."""
    hosts = []
    for line in sections.get("hv", []):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        hostname, host_vars = parse_host_line(stripped)
        if hostname is None:
            continue
        hosts.append({"hostname": hostname, "vars": host_vars})
    return hosts


def ansible_host_for_hv(hv):
    """Derive ansible_host FQDN from hv inventory vars."""
    bmc_address = hv["vars"].get("bmc_address")
    if bmc_address and bmc_address.startswith("mgmt-"):
        return bmc_address.removeprefix("mgmt-")
    return hv["hostname"]


def hv_ip_for_hv(hv):
    """Return the hypervisor control-plane IP."""
    if "ip" not in hv["vars"]:
        raise ValueError(f"Hypervisor {hv['hostname']} is missing ip= in [hv] section")
    return hv["vars"]["ip"]


def expand_cluster_instances(cluster_types, selected_cluster_types):
    """Expand selected cluster types into individual cluster instances."""
    instances = []
    sno_counter = 0
    for name in selected_cluster_types:
        cluster = cluster_types[name]
        for _ in range(int(cluster["count"])):
            instance = {"cluster_type": name, "vms": cluster["vms"]}
            if name == "sno":
                instance["sno_index"] = sno_counter
                sno_counter += 1
            instances.append(instance)
    return instances


def sno_cluster_number(entry):
    """Return the 0-based index used in sno-{n} VM names."""
    if entry.get("sno_index") is not None:
        return entry["sno_index"]
    return entry["cluster_index"] - 1


def distribute_vm_type(hvs, count, per_hv, start_idx=0):
    """
    Assign VM counts per hypervisor for one VM type.

    Place up to per_hv VMs on each hypervisor (in rotated order) before moving
    to the next. When VMs remain after all hypervisors have been visited once,
    distribute the remainder round-robin from start_idx.
    """
    assignments = [0] * len(hvs)
    if not hvs or count <= 0:
        return assignments

    remaining = count
    hv_count = len(hvs)
    for i in range(hv_count):
        if remaining <= 0:
            break
        idx = (start_idx + i) % hv_count
        placed = min(per_hv, remaining)
        assignments[idx] += placed
        remaining -= placed

    for vm_idx in range(remaining):
        idx = (start_idx + vm_idx) % hv_count
        assignments[idx] += 1

    return assignments


def hypervisors_used_by_assignment(assignments):
    """Return how many hypervisors received VMs in an assignment."""
    return sum(1 for count in assignments if count > 0)


def per_hv_for_cluster(cluster_type, vm_type, vm_types):
    """Return per_hv limit for spread placement; SNO always uses 1."""
    if cluster_type == "sno" or vm_type == "sno":
        return 1
    return int(vm_types[vm_type].get("per_hv", 1))


def build_spread_deployment_plan(hvs, vm_types, cluster_types, selected_cluster_types, start_at_hv=0):
    """Spread each cluster's VMs across hypervisors using per_hv limits per VM type."""
    plan = []
    instances = expand_cluster_instances(cluster_types, selected_cluster_types)
    hv_count = len(hvs)
    hv_offset = start_at_hv % hv_count if hv_count else 0

    for idx, instance in enumerate(instances):
        hv_cursor = (idx + hv_offset) % hv_count if hv_count else 0
        for vm_type, vm_count in instance["vms"].items():
            vm_count = int(vm_count)
            if vm_count <= 0:
                continue

            per_hv = per_hv_for_cluster(instance["cluster_type"], vm_type, vm_types)
            assignments = distribute_vm_type(hvs, vm_count, per_hv, start_idx=hv_cursor)
            for hv_idx, hv in enumerate(hvs):
                count_on_hv = assignments[hv_idx]
                if count_on_hv <= 0:
                    continue
                plan.append(
                    {
                        "host": ansible_host_for_hv(hv),
                        "hv_ip": hv_ip_for_hv(hv),
                        "count": count_on_hv,
                        "type": vm_type,
                        "disk2_enable": hv["vars"].get("disk2_enable", "False") == "True",
                        "cluster_type": instance["cluster_type"],
                        "cluster_index": idx + 1,
                        "sno_index": instance.get("sno_index"),
                    }
                )
            hv_cursor = (hv_cursor + hypervisors_used_by_assignment(assignments)) % hv_count
    return plan


def build_cluster_deployment_plan(hvs, cluster_types, selected_cluster_types, start_at_hv=0):
    """
    Place each cluster on a single hypervisor.

    One cluster uses one HV. Multiple clusters each get their own HV when
    possible. When there are more clusters than hypervisors, assign round-robin.
    """
    plan = []
    instances = expand_cluster_instances(cluster_types, selected_cluster_types)
    hv_count = len(hvs)
    hv_offset = start_at_hv % hv_count if hv_count else 0

    for idx, instance in enumerate(instances):
        hv = hvs[(idx + hv_offset) % hv_count]
        for vm_type, vm_count in instance["vms"].items():
            vm_count = int(vm_count)
            if vm_count <= 0:
                continue
            plan.append(
                {
                    "host": ansible_host_for_hv(hv),
                    "hv_ip": hv_ip_for_hv(hv),
                    "count": vm_count,
                    "type": vm_type,
                    "disk2_enable": hv["vars"].get("disk2_enable", "False") == "True",
                    "cluster_type": instance["cluster_type"],
                    "cluster_index": idx + 1,
                    "sno_index": instance.get("sno_index"),
                }
            )
    return plan


def build_deployment_plan(
    hvs, vm_types, cluster_types, selected_cluster_types, spread=False, start_at_hv=0
):
    """Build per-hypervisor VM batches using cluster-local or spread placement."""
    if spread:
        return build_spread_deployment_plan(
            hvs, vm_types, cluster_types, selected_cluster_types, start_at_hv=start_at_hv
        )
    return build_cluster_deployment_plan(
        hvs, cluster_types, selected_cluster_types, start_at_hv=start_at_hv
    )


def mac_to_int(mac_str):
    return int(mac_str.replace(":", ""), 16)


def int_to_mac(mac_int):
    s = f"{mac_int:012x}"
    return ":".join(s[i : i + 2] for i in range(0, 12, 2))


def vm_mac_address(vm_number, start_vm_id=1, start_mac="52:54:00:00:00:01"):
    """Generate a KVM/QEMU MAC address matching Jetlag inventory."""
    mac_int = mac_to_int(start_mac) + (vm_number - start_vm_id)
    return int_to_mac(mac_int)


def vm_domain_uuid(vm_number):
    """Generate a namespaced domain UUID matching Ansible's to_uuid filter."""
    return str(uuid.uuid5(ANSIBLE_UUID_NAMESPACE, str(vm_number)))


def vm_ip_from_offset(network, offset, vm_number):
    """Compute VM IP from network and 1-based VM number."""
    network = ipaddress.ip_network(network, strict=False)
    base_host = int(network.network_address) + offset + vm_number - 1
    return str(ipaddress.ip_address(base_host))


def disk_location_for_vm(template, hv_disk2_enable, vm_index_on_hv, default_disk_vms, disk2_mount_path):
    """Place early VMs on the default disk and overflow to disk2 when enabled."""
    if hv_disk2_enable and vm_index_on_hv > default_disk_vms:
        return f"{disk2_mount_path}/libvirt/images"
    return template["disk_location"]


def build_vm_name(entry, type_num, vm_number, organize_vm_names, vm_prefix):
    """Return inventory hostname for a VM based on naming options."""
    if organize_vm_names:
        if entry.get("cluster_type") == "sno":
            cluster_number = sno_cluster_number(entry)
            if entry["count"] > 1:
                return f"sno-{cluster_number}-{type_num}"
            return f"sno-{cluster_number}"
        cluster_number = entry["cluster_index"] - 1
        return f"cluster-{cluster_number}-{entry['type']}-{type_num}"

    prefix = vm_prefix if vm_prefix is not None else "vm"
    return f"{prefix}{vm_number:05d}"


def cluster_vms_summary(deployment_plan, cluster_index):
    """Summarize VM counts by type for one cluster."""
    totals = {}
    for entry in deployment_plan:
        if entry.get("cluster_index") == cluster_index:
            totals[entry["type"]] = totals.get(entry["type"], 0) + entry["count"]
    return ", ".join(f"{count} {vm_type}" for vm_type, count in totals.items())


def cluster_header_line(entry, deployment_plan):
    """Return a comment line describing a cluster block."""
    cluster_number = entry["cluster_index"] - 1
    cluster_type = entry.get("cluster_type", "?")
    vms = cluster_vms_summary(deployment_plan, entry["cluster_index"])
    return f"# cluster {cluster_number} ({cluster_type}): {vms}"


def count_vm_records(lines):
    """Count inventory host lines, excluding comments and blank separators."""
    return sum(1 for line in lines if line and not line.startswith("#"))


def generate_inventory(
    deployment_plan,
    vm_types,
    network,
    start_vm_id=1,
    vm_ip_offset=20,
    start_vnc=5901,
    start_mac="52:54:00:00:00:01",
    default_disk_vms=3,
    disk2_mount_path="/mnt/disk2",
    organize_vm_names=False,
    vm_prefix=None,
    tag_roles=False,
    sub_groups=False,
):
    output_lines = []
    cluster_groups = {}
    cluster_children = []
    curr_vm_id = start_vm_id
    hv_vnc_counters = {}
    hv_vm_counters = {}
    organized_name_counters = {}
    last_cluster_index = None

    for entry in deployment_plan:
        cluster_index = entry.get("cluster_index")
        cluster_type = entry.get("cluster_type", "?")
        group_name = cluster_group_name(cluster_type, cluster_index)

        if not sub_groups:
            if cluster_index is not None and cluster_index != last_cluster_index:
                if last_cluster_index is not None:
                    output_lines.append("")
                output_lines.append(cluster_header_line(entry, deployment_plan))
                last_cluster_index = cluster_index
        elif group_name not in cluster_groups:
            cluster_groups[group_name] = []
            cluster_children.append(group_name)

        template = vm_types[entry["type"]].copy()
        hv_key = entry["host"]
        hv_vnc_counters.setdefault(hv_key, start_vnc)
        hv_vm_counters.setdefault(hv_key, 0)

        for type_num in range(1, entry["count"] + 1):
            hv_vm_counters[hv_key] += 1
            if organize_vm_names:
                name_key = (entry["cluster_index"], entry["type"])
                organized_name_counters[name_key] = (
                    organized_name_counters.get(name_key, 0) + 1
                )
                name_type_num = organized_name_counters[name_key]
            else:
                name_type_num = type_num
            vm_id = build_vm_name(
                entry, name_type_num, curr_vm_id, organize_vm_names, vm_prefix
            )
            vm_ip = vm_ip_from_offset(network, vm_ip_offset, curr_vm_id)
            vm_mac = vm_mac_address(curr_vm_id, start_vm_id, start_mac)
            vm_uuid = vm_domain_uuid(curr_vm_id)
            vnc_port = hv_vnc_counters[hv_key]
            disk_location = disk_location_for_vm(
                template,
                entry["disk2_enable"],
                hv_vm_counters[hv_key],
                default_disk_vms,
                disk2_mount_path,
            )

            role_suffix = f" role={entry['type']}" if tag_roles else ""
            vm_line = (
                f"{vm_id} ansible_host={entry['host']} "
                f"hv_ip={entry['hv_ip']} ip={vm_ip} "
                f"cpus={template['cpus']} memory={template['memory']} "
                f"disk_size={template['disk_size']} vnc_port={vnc_port} "
                f"mac_address={vm_mac} domain_uuid={vm_uuid} "
                f"disk_location={disk_location} "
                f"bw_avg={template['bw_avg']} bw_peak={template['bw_peak']} "
                f"bw_burst={template['bw_burst']}"
                f"{misc_fields_suffix(template.get('misc'))}"
                f"{role_suffix}"
            )

            if sub_groups:
                cluster_groups[group_name].append(vm_line)
            else:
                output_lines.append(vm_line)

            curr_vm_id += 1
            hv_vnc_counters[hv_key] += 1

    if sub_groups:
        return InventoryOutput(
            cluster_groups=cluster_groups,
            children=cluster_children,
            sub_groups=True,
        )
    return InventoryOutput(flat_lines=output_lines, sub_groups=False)


def controlplane_network_from_sections(sections):
    """Read controlplane_network from [all:vars]."""
    for line in sections.get("all:vars", []):
        match = VAR_RE.match(line.strip())
        if match and match.group(1) == "controlplane_network":
            value = match.group(2).strip()
            if value.startswith("[") and value.endswith("]"):
                value = value[1:-1].strip().strip("'\"")
            return value
    return "198.18.0.0/16"


def inventory_base_name(inventory_path):
    """Return the inventory basename without a trailing .local suffix."""
    path = Path(inventory_path)
    if path.suffix == ".local":
        return path.stem
    return path.name


def vm_composition_segment(vm_counts):
    """
    Format VM counts as a filename segment, e.g. 3m-2w.

    Each VM type contributes {count}{first letter of type name}.
    """
    parts = []
    for vm_type, count in vm_counts.items():
        count = int(count)
        if count > 0:
            parts.append(f"{count}{vm_type[0].lower()}")
    return "-".join(parts)


def parse_selected_cluster_type(cluster_type_arg):
    """Return a single cluster type name from CLI input."""
    types = [name.strip() for name in cluster_type_arg.split(",") if name.strip()]
    if not types:
        raise ValueError("Cluster type must be provided via --cluster-type")
    if len(types) > 1:
        raise ValueError(
            "Only one cluster type is allowed per run. Define a custom cluster type "
            "in the topology file for mixed VM layouts."
        )
    return types[0]


def build_output_inventory_path(inventory_path, cluster_types, cluster_type):
    """
    Build output inventory path:
    {original_name}-{count}{type}-{vm counts}.local

    VM count segment uses each VM type's count and first letter, e.g. 3m-2w.
    """
    base = inventory_base_name(inventory_path)
    parent = Path(inventory_path).parent
    cluster = cluster_types[cluster_type]
    cluster_segment = f"{int(cluster['count'])}{cluster_type}"
    vm_segment = vm_composition_segment(cluster["vms"])
    filename = f"{base}-{cluster_segment}-{vm_segment}.local"
    return parent / filename


def resolve_output_path(inventory_file, cluster_types, cluster_type, overwrite_original):
    """Return the inventory path that would be written."""
    if overwrite_original:
        return Path(inventory_file).resolve()
    return build_output_inventory_path(
        inventory_file,
        cluster_types,
        cluster_type,
    ).resolve()


def summarize_vm_type(vm_type, template):
    """Return a short hardware summary for a VM type."""
    per_hv = template.get("per_hv", 1)
    return (
        f"{template['cpus']} CPU, {template['memory']} GB RAM, "
        f"{template['disk_size']} GB disk, per_hv={per_hv}"
    )


def compute_hv_detailed_loads(
    deployment_plan, vm_types, default_disk_vms=3, disk2_mount_path="/mnt/disk2"
):
    """Sum planned resources per hypervisor, including disk use per image path."""
    loads = {}
    vm_counters = {}
    for entry in deployment_plan:
        host = entry["host"]
        template = vm_types[entry["type"]]
        count = int(entry["count"])
        disk2_enable = entry.get("disk2_enable", False)

        load = loads.setdefault(
            host,
            {"cpus": 0, "memory": 0, "vms": 0, "disk_by_path": {}},
        )
        vm_counters.setdefault(host, 0)

        for _ in range(count):
            vm_counters[host] += 1
            disk_path = disk_location_for_vm(
                template,
                disk2_enable,
                vm_counters[host],
                default_disk_vms,
                disk2_mount_path,
            )
            load["disk_by_path"][disk_path] = (
                load["disk_by_path"].get(disk_path, 0) + int(template["disk_size"])
            )
            load["cpus"] += int(template["cpus"])
            load["memory"] += int(template["memory"])
            load["vms"] += 1
    return loads


def compute_hv_loads(
    deployment_plan, vm_types, default_disk_vms=3, disk2_mount_path="/mnt/disk2"
):
    """Sum CPU, memory, disk, and VM count per hypervisor host."""
    loads = {}
    for host, detailed in compute_hv_detailed_loads(
        deployment_plan, vm_types, default_disk_vms, disk2_mount_path
    ).items():
        loads[host] = {
            "cpus": detailed["cpus"],
            "memory": detailed["memory"],
            "disk": sum(detailed["disk_by_path"].values()),
            "vms": detailed["vms"],
            "disk_by_path": detailed["disk_by_path"],
        }
    return loads


def format_hv_load(load):
    """Format cumulative hypervisor resource usage."""
    if load["vms"] == 0:
        return "no VMs assigned"
    vm_label = "VM" if load["vms"] == 1 else "VMs"
    return (
        f"{load['cpus']} CPU, {load['memory']} GB RAM, "
        f"{load['disk']} GB disk ({load['vms']} {vm_label})"
    )


def hv_ssh_credentials(hv, hv_section_vars):
    """Return SSH user and password from host or [hv:vars] inventory vars."""
    user = hv["vars"].get("ansible_user") or hv_section_vars.get("ansible_user")
    password = hv["vars"].get("ansible_ssh_pass") or hv_section_vars.get(
        "ansible_ssh_pass"
    )
    if not user:
        raise ValueError(
            "ansible_user not found in [hv:vars] or hypervisor host vars "
            "(required for --assess-hv)"
        )
    if not password:
        raise ValueError(
            "ansible_ssh_pass not found in [hv:vars] or hypervisor host vars "
            "(required for --assess-hv)"
        )
    return user, password


def disk_paths_for_hv(hv, vm_types, disk2_mount_path):
    """Return libvirt image paths that may be used on a hypervisor."""
    paths = {
        template.get("disk_location", "/var/lib/libvirt/images")
        for template in vm_types.values()
    }
    if hv["vars"].get("disk2_enable", "False") == "True":
        paths.add(f"{disk2_mount_path}/libvirt/images")
    return sorted(paths)


def require_sshpass():
    """Ensure sshpass is available for password-based SSH."""
    if not shutil.which("sshpass"):
        raise RuntimeError("--assess-hv requires sshpass to be installed")


def build_remote_resource_script(disk_paths):
    """Build a remote shell snippet reporting CPU, memory, and disk availability."""
    paths_shell = " ".join(shlex.quote(path) for path in disk_paths)
    return (
        "cpu=$(nproc); "
        "mem_kb=$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo); "
        f"for path in {paths_shell}; do "
        'target="$path"; [ -e "$path" ] || target=$(dirname "$path"); '
        "avail_kb=$(df -P \"$target\" 2>/dev/null | awk 'NR==2 {print $4}'); "
        '[ -n "$avail_kb" ] && echo "DISK:$path:$((avail_kb / 1024 / 1024))"; '
        "done; "
        'echo "CPU:$cpu"; '
        'echo "MEM:$((mem_kb / 1024 / 1024))"'
    )


def parse_remote_capacity(stdout):
    """Parse CPU, memory, and per-path disk availability from remote output."""
    capacity = {"cpus": 0, "memory": 0, "disk_by_path": {}}
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("CPU:"):
            capacity["cpus"] = int(line.split(":", 1)[1])
        elif line.startswith("MEM:"):
            capacity["memory"] = int(line.split(":", 1)[1])
        elif line.startswith("DISK:"):
            _, path, gb = line.split(":", 2)
            capacity["disk_by_path"][path] = int(gb)
    return capacity


def fetch_hv_capacity(ip, user, password, disk_paths, timeout=30):
    """SSH to a hypervisor and return available CPU, memory, and disk space."""
    require_sshpass()
    remote_command = build_remote_resource_script(disk_paths)
    cmd = [
        "sshpass",
        "-p",
        password,
        "ssh",
        "-o",
        "StrictHostKeyChecking=no",
        "-o",
        "UserKnownHostsFile=/dev/null",
        "-o",
        "LogLevel=ERROR",
        f"{user}@{ip}",
        remote_command,
    ]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"SSH to {user}@{ip} timed out after {timeout}s") from exc

    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(
            f"SSH to {user}@{ip} failed"
            + (f": {detail}" if detail else "")
        )
    return parse_remote_capacity(result.stdout)


def format_capacity(capacity):
    """Format hypervisor capacity for dry-run output."""
    disk_parts = [
        f"{gb} GB ({path})" for path, gb in sorted(capacity["disk_by_path"].items())
    ]
    disk_str = ", ".join(disk_parts) if disk_parts else "unknown"
    return (
        f"capacity: {capacity['cpus']} CPU, {capacity['memory']} GB RAM, "
        f"disk {disk_str}"
    )


def assess_hv_warnings(load, capacity):
    """Return CPU/disk overcommit and memory capacity warnings."""
    warnings = []

    if load["cpus"] > capacity["cpus"]:
        if capacity["cpus"] > 0:
            overcommit = load["cpus"] / capacity["cpus"]
            warnings.append(
                f"CPU overcommit: {overcommit:.2f}x "
                f"({load['cpus']} vCPUs planned, {capacity['cpus']} CPUs available)"
            )
        else:
            warnings.append(
                f"WARNING: CPU demand exceeds capacity "
                f"({load['cpus']} vCPUs planned, 0 CPUs reported)"
            )

    if load["memory"] > capacity["memory"]:
        warnings.append(
            f"WARNING: memory exceeds capacity "
            f"({load['memory']} GB planned, {capacity['memory']} GB available)"
        )

    for path, planned in sorted(load.get("disk_by_path", {}).items()):
        available = capacity["disk_by_path"].get(path, 0)
        if planned > available:
            if available > 0:
                overcommit = planned / available
                warnings.append(
                    f"Disk overcommit on {path}: {overcommit:.2f}x "
                    f"({planned} GB planned, {available} GB available)"
                )
            else:
                warnings.append(
                    f"WARNING: disk exceeds capacity on {path} "
                    f"({planned} GB planned, {available} GB available)"
                )

    return warnings


def print_hypervisors(
    hvs,
    deployment_plan,
    vm_types,
    assess=False,
    hv_section_vars=None,
    default_disk_vms=3,
    disk2_mount_path="/mnt/disk2",
):
    """Print hypervisors with cumulative planned resource load."""
    loads = compute_hv_loads(
        deployment_plan, vm_types, default_disk_vms, disk2_mount_path
    )
    hv_section_vars = hv_section_vars or {}
    if assess:
        require_sshpass()

    print(f"Hypervisors ({len(hvs)})")
    print("-" * 60)
    for hv in hvs:
        host = ansible_host_for_hv(hv)
        ip = hv_ip_for_hv(hv)
        short = hv["hostname"].split(".")[0]
        disk2 = hv["vars"].get("disk2_enable", "False")
        load = loads.get(
            host,
            {"cpus": 0, "memory": 0, "disk": 0, "vms": 0, "disk_by_path": {}},
        )
        print(f"  {short} ({ip})  disk2={disk2}")
        if assess:
            print(f"    planned: {format_hv_load(load)}")
        else:
            print(f"    {format_hv_load(load)}")

        if not assess:
            continue

        try:
            user, password = hv_ssh_credentials(hv, hv_section_vars)
            disk_paths = disk_paths_for_hv(hv, vm_types, disk2_mount_path)
            capacity = fetch_hv_capacity(ip, user, password, disk_paths)
        except (RuntimeError, ValueError) as exc:
            print(f"    assessment failed: {exc}")
            continue

        print(f"    {format_capacity(capacity)}")
        for warning in assess_hv_warnings(load, capacity):
            print(f"    {warning}")


def print_hv_distribution(deployment_plan, spread=False):
    """Print cluster- and hypervisor-grouped placement for dry-run output."""
    clusters = {}
    for entry in deployment_plan:
        cluster_key = entry.get("cluster_index", 0)
        clusters.setdefault(
            cluster_key,
            {
                "cluster_type": entry.get("cluster_type", "?"),
                "entries": [],
            },
        )
        clusters[cluster_key]["entries"].append(entry)

    title = "HV distribution (spread)" if spread else "HV distribution"
    print(title)
    print("-" * 60)
    for cluster_key in sorted(clusters):
        cluster = clusters[cluster_key]
        print(f"  cluster {cluster_key} ({cluster['cluster_type']})")

        hypervisors = {}
        for entry in cluster["entries"]:
            host = entry["host"].split(".")[0]
            hypervisors.setdefault(
                host,
                {"hv_ip": entry["hv_ip"], "vms": []},
            )
            hypervisors[host]["vms"].append(entry)

        for host, hv in hypervisors.items():
            print(f"    {host} ({hv['hv_ip']})")
            for vm in hv["vms"]:
                if spread:
                    print(f"      {vm['type']} x{vm['count']}")
                else:
                    print(f"      {vm['count']} {vm['type']}")


def print_short_hv_vm_section(inventory_output):
    """Print only the [hv_vm] inventory section for copy-paste."""
    for block in format_vm_inventory_blocks(inventory_output):
        print(block)


def print_dry_run_summary(
    args,
    vm_types,
    cluster_types,
    cluster_type,
    hvs,
    network,
    deployment_plan,
    inventory_output,
    output_path,
    sections,
):
    """Print a human-readable preview without writing any files."""
    inventory_path = Path(args.inventory_file).resolve()
    topology_source = str(Path(args.vm_types).resolve()) if args.vm_types else "built-in defaults"
    overwrite = args.overwrite_original
    vm_counts = aggregate_vm_counts(cluster_types, [cluster_type])

    print("VM Planner — dry run")
    print("=" * 60)
    print()

    print("Input")
    print("-" * 60)
    print(f"  Inventory file : {inventory_path}")
    print(f"  Topology       : {topology_source}")
    print(f"  Cluster type   : {cluster_type}")
    print(f"  Placement      : {'spread across hypervisors' if args.spread else 'one cluster per hypervisor'}")
    if args.start_at_hv != 0:
        hv_idx = args.start_at_hv % len(hvs)
        print(f"  Start at HV    : {args.start_at_hv} ({hvs[hv_idx]['hostname']})")
    print(f"  Network        : {network}")
    print(f"  VM IP offset   : {args.vm_ip_offset}")
    print(f"  Start VM ID    : vm{args.start_vm_id:05d}")
    if args.organize_vm_names:
        if cluster_type == "sno":
            print("  VM naming      : sno-{index}")
        else:
            print("  VM naming      : cluster-{n}-{type}-{instance}")
    elif args.vm_prefix is not None:
        print(f"  VM naming      : {args.vm_prefix}{{index}}")
    else:
        print(f"  VM naming      : vm{{index:05d}} (from vm{args.start_vm_id:05d})")
    if args.tag_roles:
        print("  VM roles       : role={vm type} on each record")
    if args.sub_groups:
        print("  VM layout      : [hv_vm:children] with per-cluster sub-groups")
    print()

    print_hypervisors(
        hvs,
        deployment_plan,
        vm_types,
        assess=args.assess_hv,
        hv_section_vars=parse_section_vars(sections, "hv:vars"),
        default_disk_vms=args.default_disk_vms,
        disk2_mount_path=args.disk2_mount_path,
    )
    print()

    print("Cluster composition")
    print("-" * 60)
    cluster = cluster_types[cluster_type]
    count = int(cluster["count"])
    vms = cluster["vms"]
    per_cluster = ", ".join(f"{n} {t}" for t, n in vms.items())
    cluster_vms = sum(int(n) for n in vms.values())
    print(
        f"  {cluster_type:<12} x{count}  ({per_cluster} per cluster, "
        f"{cluster_vms * count} VMs total)"
    )
    print()

    print("VM totals")
    print("-" * 60)
    for vm_type, total in sorted(vm_counts.items()):
        print(f"  {vm_type:<12} {total:>3}  ({summarize_vm_type(vm_type, vm_types[vm_type])})")
    print()

    print_hv_distribution(deployment_plan, spread=args.spread)
    print()

    print("Output")
    print("-" * 60)
    append_target_exists = output_path.exists()
    if args.append:
        if overwrite or append_target_exists:
            action = "append records to"
            if overwrite:
                print(f"  Action         : {action} original inventory file")
            else:
                print(f"  Action         : {action} existing inventory file")
            print(f"  Path           : {output_path}")
            if not overwrite:
                print(f"  Original file  : unchanged ({inventory_path})")
        else:
            print("  Action         : create new inventory file")
            print(f"  Path           : {output_path}")
            print(f"  Original file  : unchanged ({inventory_path})")
            print(
                "  Note           : --append has no effect; output file does not "
                "exist yet"
            )
    elif overwrite:
        print("  Action         : modify original inventory file")
        print(f"  Path           : {output_path}")
    else:
        print("  Action         : create new inventory file")
        print(f"  Path           : {output_path}")
        print(f"  Original file  : unchanged ({inventory_path})")
    print()

    print(f"[hv_vm] records ({count_vm_records(inventory_output.all_vm_lines())})")
    print("-" * 60)
    for block in format_vm_inventory_blocks(inventory_output):
        print(block)
    print()
    print("No files were modified.")


def write_hv_vm_section(source_path, inventory_output, output_path, append=False):
    """Write inventory with VM host entries, reading from source_path."""
    if append:
        if inventory_output.sub_groups:
            raise ValueError("--sub-groups cannot be used with --append")

        source_sections = parse_inventory(source_path)
        if inventory_uses_sub_groups(source_sections):
            raise ValueError(
                "--append cannot be used on inventories generated with --sub-groups. "
                "Re-run without --append to regenerate the inventory."
            )

    lines = Path(source_path).read_text().splitlines(keepends=True)
    output = []
    in_replaceable_section = False
    vm_sections_written = False
    section_header_pending = False
    appended_in_section = False

    def append_generated_sections():
        nonlocal vm_sections_written
        for block in format_vm_inventory_blocks(inventory_output):
            output.append(block + "\n")
        vm_sections_written = True

    for line in lines:
        stripped = line.strip()
        section_match = SECTION_RE.match(stripped)

        if section_match:
            section_name = section_match.group(1)

            if in_replaceable_section and not is_replaceable_vm_section(section_name):
                if (
                    append
                    and not inventory_output.sub_groups
                    and not appended_in_section
                ):
                    for vm_line in inventory_output.all_vm_lines():
                        output.append(vm_line + "\n")
                    appended_in_section = True
                in_replaceable_section = False
                section_header_pending = False

            if is_replaceable_vm_section(section_name):
                if not vm_sections_written:
                    if section_name == "hv_vm" and append:
                        output.append(line if line.endswith("\n") else line + "\n")
                        in_replaceable_section = True
                        appended_in_section = False
                        section_header_pending = False
                        continue
                    append_generated_sections()
                in_replaceable_section = True
                section_header_pending = False
                continue

            output.append(line if line.endswith("\n") else line + "\n")
            continue

        if in_replaceable_section:
            if append and not inventory_output.sub_groups:
                if section_header_pending:
                    section_header_pending = False
                    if stripped and not stripped.startswith("#"):
                        continue
                if stripped.startswith("#") or not stripped:
                    if stripped.startswith("# Unused"):
                        continue
                    if not stripped:
                        continue
                    output.append(line if line.endswith("\n") else line + "\n")
                    continue
            continue

        output.append(line if line.endswith("\n") else line + "\n")

    if not vm_sections_written:
        if output and not output[-1].endswith("\n"):
            output[-1] += "\n"
        append_generated_sections()
    elif (
        in_replaceable_section
        and append
        and not appended_in_section
        and not inventory_output.sub_groups
    ):
        for vm_line in inventory_output.all_vm_lines():
            output.append(vm_line + "\n")

    Path(output_path).write_text("".join(output))


def resolve_write_source(inventory_file, output_path, overwrite_original, append):
    """Return source inventory path and whether append mode is active."""
    if not append:
        return inventory_file, False

    if overwrite_original or output_path.exists():
        if overwrite_original:
            return inventory_file, True
        return output_path, True

    return inventory_file, False


def parse_args():
    parser = argparse.ArgumentParser(
        description="Generate Ansible [hv_vm] inventory records from [hv] hosts."
    )
    parser.add_argument(
        "--vm-types",
        metavar="PATH",
        help="Path to a topology file (JSON, YAML, or Python) with vm_types and cluster_types",
    )
    parser.add_argument(
        "--cluster-type",
        metavar="NAME",
        default="vmno",
        help=(
            "Cluster type to deploy (default: vmno). Must exist in cluster_types. "
            "Only one type per run; define a custom cluster type for mixed layouts."
        ),
    )
    parser.add_argument(
        "--inventory-file",
        metavar="PATH",
        required=True,
        help="Ansible inventory file with a [hv] section",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print a summary of planned changes without writing any files",
    )
    parser.add_argument(
        "--short",
        action="store_true",
        help=(
            "With --dry-run, print only the [hv_vm] section (no summary) for "
            "copy-paste into an inventory file"
        ),
    )
    parser.add_argument(
        "--spread",
        action="store_true",
        help=(
            "Spread VMs across hypervisors by VM type using per_hv limits. "
            "Default: keep each cluster on a single hypervisor"
        ),
    )
    parser.add_argument(
        "--organize-vm-names",
        action="store_true",
        help=(
            "Name VMs as cluster-{n}-{type}-{instance}, or sno-{index} for sno "
            "clusters (e.g. cluster-0-master-1, sno-0)"
        ),
    )
    parser.add_argument(
        "--vm-prefix",
        metavar="PREFIX",
        help="Override default vm prefix for sequential names (e.g. node -> node00001)",
    )
    parser.add_argument(
        "--tag-roles",
        action="store_true",
        help="Add role={vm type} to each [hv_vm] record (e.g. role=master, role=worker)",
    )
    parser.add_argument(
        "--sub-groups",
        action="store_true",
        help=(
            "Place each cluster in its own inventory sub-group under [hv_vm:children] "
            "(vm_cluster_{type}_{index})"
        ),
    )
    parser.add_argument(
        "--append",
        action="store_true",
        help=(
            "Append generated [hv_vm] records to an existing inventory file "
            "instead of replacing them"
        ),
    )
    parser.add_argument(
        "--overwrite-original",
        action="store_true",
        help=(
            "Write generated [hv_vm] records into --inventory-file instead of "
            "creating a new file with a derived name"
        ),
    )
    parser.add_argument(
        "--assess-hv",
        action="store_true",
        help=(
            "SSH to each hypervisor using ansible_user and ansible_ssh_pass from "
            "[hv:vars] and compare planned load against available CPU, memory, and disk"
        ),
    )
    parser.add_argument(
        "--start-at-hv",
        type=int,
        default=0,
        metavar="N",
        help=(
            "0-based index of the first hypervisor in [hv] to use for placement "
            "(default: 0, the first hypervisor). Rotates round-robin from there."
        ),
    )
    parser.add_argument(
        "--vm-ip-offset",
        type=int,
        default=20,
        help="Host offset within controlplane_network for VM IPs (default: 20)",
    )
    parser.add_argument(
        "--start-vm-id",
        type=int,
        default=1,
        help="First VM numeric ID (default: 1 -> vm00001)",
    )
    parser.add_argument(
        "--start-mac",
        default="52:54:00:00:00:01",
        help="Starting MAC address (default: 52:54:00:00:00:01)",
    )
    parser.add_argument(
        "--start-vnc",
        type=int,
        default=5901,
        help="Starting VNC port per hypervisor (default: 5901)",
    )
    parser.add_argument(
        "--default-disk-vms",
        type=int,
        default=3,
        help="VMs per hypervisor placed on the default disk before disk2 (default: 3)",
    )
    parser.add_argument(
        "--disk2-mount-path",
        default="/mnt/disk2",
        help="Mount path used when disk2_enable=True (default: /mnt/disk2)",
    )
    return parser.parse_args()


def report_error(message):
    """Print a user-facing error and return exit code 1."""
    print(message, file=sys.stderr)
    return 1


def cli_main():
    """Run main() and translate errors into user-friendly messages."""
    try:
        return main()
    except FileNotFoundError as exc:
        return report_error(str(exc))
    except json.JSONDecodeError as exc:
        return report_error(
            f"Invalid JSON in topology file: {exc.msg} "
            f"(line {exc.lineno}, column {exc.colno})"
        )
    except SyntaxError as exc:
        filename = exc.filename or "topology file"
        return report_error(f"Invalid Python in {filename}: {exc.msg}")
    except (ValueError, RuntimeError) as exc:
        return report_error(str(exc))
    except PermissionError as exc:
        target = exc.filename or "file"
        return report_error(f"Permission denied: {target}")
    except OSError as exc:
        return report_error(str(exc))


def main():
    args = parse_args()

    vm_types = DEFAULT_VM_TYPES
    cluster_types = DEFAULT_CLUSTER_TYPES
    if args.vm_types:
        vm_types, cluster_types = load_config(args.vm_types)

    validate_vm_types(vm_types)
    validate_cluster_types(cluster_types, vm_types)

    try:
        cluster_type = parse_selected_cluster_type(args.cluster_type)
    except ValueError as exc:
        return report_error(str(exc))

    if args.short and not args.dry_run:
        return report_error("--short requires --dry-run")
    if args.short and args.assess_hv:
        return report_error("--short cannot be used with --assess-hv")
    if args.sub_groups and args.append:
        return report_error("--sub-groups cannot be used with --append")
    if args.start_at_hv < 0:
        return report_error("--start-at-hv must be >= 0")

    vm_counts = aggregate_vm_counts(cluster_types, [cluster_type])

    if not vm_counts:
        return report_error("No VMs to generate; check cluster type count values")

    planned_vm_types = vm_types_with_counts(vm_types, vm_counts)

    sections = parse_inventory(args.inventory_file)
    if args.append and inventory_uses_sub_groups(sections):
        return report_error(
            "--append cannot be used on inventories generated with --sub-groups. "
            "Re-run without --append to regenerate the inventory."
        )

    hvs = parse_hv_hosts(sections)
    if not hvs:
        return report_error("No hypervisor hosts found in [hv] section")
    if args.start_at_hv >= len(hvs):
        return report_error(
            f"--start-at-hv {args.start_at_hv} exceeds hypervisor count ({len(hvs)}; "
            f"valid range is 0-{len(hvs) - 1})"
        )

    network = controlplane_network_from_sections(sections)
    deployment_plan = build_deployment_plan(
        hvs,
        vm_types,
        cluster_types,
        [cluster_type],
        spread=args.spread,
        start_at_hv=args.start_at_hv,
    )
    if not deployment_plan:
        return report_error("No VMs to generate; check cluster type VM composition")

    inventory_output = generate_inventory(
        deployment_plan,
        planned_vm_types,
        network=network,
        start_vm_id=args.start_vm_id,
        vm_ip_offset=args.vm_ip_offset,
        start_vnc=args.start_vnc,
        start_mac=args.start_mac,
        default_disk_vms=args.default_disk_vms,
        disk2_mount_path=args.disk2_mount_path,
        organize_vm_names=args.organize_vm_names,
        vm_prefix=args.vm_prefix,
        tag_roles=args.tag_roles,
        sub_groups=args.sub_groups,
    )

    output_path = resolve_output_path(
        args.inventory_file,
        cluster_types,
        cluster_type,
        args.overwrite_original,
    )

    write_source, append_active = resolve_write_source(
        args.inventory_file,
        output_path,
        args.overwrite_original,
        args.append,
    )

    if append_active and inventory_uses_sub_groups(parse_inventory(write_source)):
        return report_error(
            "--append cannot be used on inventories generated with --sub-groups. "
            "Re-run without --append to regenerate the inventory."
        )

    if args.dry_run:
        if args.short:
            print_short_hv_vm_section(inventory_output)
        else:
            print_dry_run_summary(
                args,
                vm_types,
                cluster_types,
                cluster_type,
                hvs,
                network,
                deployment_plan,
                inventory_output,
                output_path,
                sections,
            )
        return 0

    if args.assess_hv:
        print()
        print_hypervisors(
            hvs,
            deployment_plan,
            vm_types,
            assess=True,
            hv_section_vars=parse_section_vars(sections, "hv:vars"),
            default_disk_vms=args.default_disk_vms,
            disk2_mount_path=args.disk2_mount_path,
        )
        print()

    vm_record_count = count_vm_records(inventory_output.all_vm_lines())
    write_hv_vm_section(write_source, inventory_output, output_path, append=append_active)

    if args.append and not append_active:
        print(
            f"Note: --append has no effect; {output_path} does not exist. "
            f"Created new file."
        )
        print(f"Wrote {vm_record_count} VM records to {output_path}")
    elif append_active:
        print(f"Appended {vm_record_count} VM records to {output_path}")
    else:
        print(f"Wrote {vm_record_count} VM records to {output_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(cli_main())
