#!/usr/bin/env python3
"""Extensive validation suite for vm-planner.py."""

import importlib.util
import io
import json
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from collections import Counter, defaultdict
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

SCRIPT_DIR = Path(__file__).resolve().parent
VM_PLANNER = SCRIPT_DIR / "vm-planner.py"
INVENTORY = SCRIPT_DIR / "test_cloud00.local"
TOPOLOGY = SCRIPT_DIR / "test_topology.json"
BACKUP = SCRIPT_DIR / "test_cloud00.local.backup"

REQUIRED_FIELDS = {
    "ansible_host",
    "hv_ip",
    "ip",
    "cpus",
    "memory",
    "disk_size",
    "vnc_port",
    "mac_address",
    "domain_uuid",
    "disk_location",
    "bw_avg",
    "bw_peak",
    "bw_burst",
    "cluster",
}
MAC_RE = re.compile(r"^52:54:00:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$", re.I)
UUID_RE = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
    re.I,
)

passed = 0
failed = 0
skipped = 0
failures = []


def load_module():
    spec = importlib.util.spec_from_file_location("vm_planner", VM_PLANNER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def record(name, ok, detail=""):
    global passed, failed
    if ok:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        msg = f"  FAIL  {name}" + (f": {detail}" if detail else "")
        print(msg)
        failures.append(msg)
    return ok


def skip(name, reason):
    global skipped
    skipped += 1
    print(f"  SKIP  {name}: {reason}")


def run_cli(args, inventory=INVENTORY):
    cmd = [sys.executable, str(VM_PLANNER), "--inventory-file", str(inventory)]
    cmd.extend(args)
    return subprocess.run(cmd, capture_output=True, text=True)


def parse_vm_line(line):
    tokens = line.split()
    fields = {"name": tokens[0]}
    for token in tokens[1:]:
        if "=" in token:
            key, value = token.split("=", 1)
            fields[key] = value
    return fields


def expected_vm_count(vp, cluster_type, topology_path=TOPOLOGY):
    vm_types, cluster_types = vp.load_config(topology_path)
    totals = vp.aggregate_vm_counts(cluster_types, [cluster_type])
    return sum(totals.values())


def plan_cluster_hosts(plan):
    """Map cluster_index -> set of hypervisor hosts (cluster-local check)."""
    clusters = defaultdict(set)
    for entry in plan:
        clusters[entry["cluster_index"]].add(entry["host"])
    return clusters


def run_internal_tests(vp):
    print("\n== Internal unit checks ==")

    assignments = vp.distribute_vm_type([0] * 6, 10, 3, start_idx=0)
    record(
        "distribute_vm_type fill-then-round-robin",
        assignments == [3, 3, 3, 1, 0, 0],
        str(assignments),
    )

    assignments = vp.distribute_vm_type([0] * 6, 2, 1, start_idx=2)
    record(
        "distribute_vm_type rotated start",
        assignments[2] == 1 and assignments[3] == 1 and sum(assignments) == 2,
        str(assignments),
    )

    path = vp.build_output_inventory_path(
        INVENTORY,
        {"standard": {"count": 12, "vms": {"master": 3, "worker": 3}}},
        "standard",
    )
    record(
        "output filename standard",
        path.name == "test_cloud00-12standard-3m-3w.local",
        path.name,
    )

    path = vp.build_output_inventory_path(
        INVENTORY,
        {"crazy": {"count": 12, "vms": {"master": 3, "worker": 2, "alex": 2}}},
        "crazy",
    )
    record(
        "output filename crazy",
        path.name == "test_cloud00-12crazy-3m-2w-2a.local",
        path.name,
    )

    try:
        vp.parse_selected_cluster_type("standard,sno")
        record("reject multiple cluster types", False, "no error raised")
    except ValueError:
        record("reject multiple cluster types", True)

    record(
        "resolve_topology_path explicit",
        vp.resolve_topology_path(str(TOPOLOGY)) == Path(TOPOLOGY),
        str(vp.resolve_topology_path(str(TOPOLOGY))),
    )
    with patch.object(vp, "DEFAULT_TOPOLOGY_FILE", Path("/no/such/topology.json")):
        try:
            vp.resolve_topology_path(None)
            record("resolve_topology_path absent", False, "no error raised")
        except FileNotFoundError as exc:
            record(
                "resolve_topology_path absent",
                "topology.json" in str(exc),
                str(exc),
            )

    workdir = Path(tempfile.mkdtemp(prefix="vm-planner-topo-default-"))
    try:
        default_topo = workdir / "topology.json"
        default_topo.write_text(TOPOLOGY.read_text())
        with patch.object(vp, "DEFAULT_TOPOLOGY_FILE", default_topo):
            record(
                "resolve_topology_path default file",
                vp.resolve_topology_path(None) == default_topo,
                str(vp.resolve_topology_path(None)),
            )
    finally:
        shutil.rmtree(workdir)

    script = vp.build_remote_resource_script(["/var/lib/libvirt/images"])
    record(
        "assess-hv script uses MemTotal",
        "MemTotal:" in script and "MemAvailable:" not in script,
    )
    record(
        "assess-hv script uses lscpu for CPU count",
        "lscpu" in script and "cpu=$(nproc)" not in script,
    )
    record(
        "assess-hv script uses df total size for disk",
        "total_kb=$(df" in script and "print $2" in script and "print $4" not in script,
    )

    capacity = vp.parse_remote_capacity(
        "CPU:80\nMEM:256\nDISK:/var/lib/libvirt/images:400\n"
    )
    record(
        "parse_remote_capacity reads CPU and memory",
        capacity == {
            "cpus": 80,
            "memory": 256,
            "disk_by_path": {"/var/lib/libvirt/images": 400},
        },
        str(capacity),
    )

    warnings = vp.assess_hv_warnings(
        {"cpus": 96, "memory": 300, "disk_by_path": {"/var/lib/libvirt/images": 500}},
        {"cpus": 80, "memory": 256, "disk_by_path": {"/var/lib/libvirt/images": 400}},
    )
    record(
        "assess_hv_warnings flags CPU/memory/disk overcommit",
        len(warnings) == 3
        and "CPUs total" in warnings[0]
        and "GB total" in warnings[1]
        and "GB total" in warnings[2],
        str(warnings),
    )

    record(
        "memory_overcommitted detects planned memory above total",
        vp.memory_overcommitted({"memory": 300}, {"memory": 256}),
    )
    record(
        "memory_overcommitted allows planned memory within total",
        not vp.memory_overcommitted({"memory": 200}, {"memory": 256}),
    )

    metadata = vp.deployment_cluster_metadata(
        [
            {"cluster_index": 1, "cluster_type": "standard"},
            {"cluster_index": 2, "cluster_type": "standard"},
        ]
    )
    record(
        "deployment_cluster_metadata counts clusters and types",
        metadata == {
            "vm_cluster_count": "2",
            "vm_cluster_type_list": '["standard"]',
            "vm_cluster_list": '["cluster1", "cluster2"]',
        },
        str(metadata),
    )
    record(
        "merge_hv_vm_vars append combines cluster metadata",
        vp.merge_hv_vm_vars(
            {
                "vm_cluster_count": "1",
                "vm_cluster_type_list": '["compact"]',
                "vm_cluster_list": '["cluster1"]',
                "ansible_user": "root",
            },
            {
                "vm_cluster_count": "2",
                "vm_cluster_type_list": '["standard"]',
                "vm_cluster_list": '["cluster1", "cluster2"]',
            },
            append=True,
        )
        == {
            "vm_cluster_count": "3",
            "vm_cluster_type_list": '["compact", "standard"]',
            "vm_cluster_list": '["cluster1", "cluster2"]',
            "ansible_user": "root",
        },
    )

    record(
        "vm-planner hv_vm:vars keys do not collide with Jetlag",
        not vp.VM_PLANNER_HV_VM_VARS_KEYS & vp.JETLAG_HV_VM_VARS_KEYS,
    )
    record(
        "vm-planner hv_vm host keys do not collide with Jetlag",
        not vp.VM_PLANNER_HV_VM_HOST_KEYS & vp.JETLAG_HV_VM_HOST_KEYS,
    )

    repo_root = SCRIPT_DIR.parent.parent
    planner_var_hits = []
    for path in repo_root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix not in {".yml", ".yaml", ".j2", ".md", ".local", ".sample"}:
            continue
        try:
            rel = path.relative_to(repo_root)
        except ValueError:
            continue
        if str(rel).startswith("scripts/vm-planner/"):
            continue
        text = path.read_text(errors="ignore")
        for var_name in vp.VM_PLANNER_HV_VM_VARS_KEYS:
            if f"{var_name}=" in text:
                planner_var_hits.append(f"{rel}: {var_name}")
    record(
        "vm_cluster_* vars are unique outside vm-planner",
        not planner_var_hits,
        "; ".join(planner_var_hits),
    )


def expected_cluster_hosts(hvs, vp, cluster_count, start_at_hv):
    """Return expected one-HV-per-cluster hostnames for cluster-local placement."""
    hv_count = len(hvs)
    offset = start_at_hv
    return [
        vp.ansible_host_for_hv(hvs[(idx + offset) % hv_count])
        for idx in range(cluster_count)
    ]


def cluster_host_map(plan):
    """Map cluster_index -> set of hypervisor hosts used by that cluster."""
    clusters = defaultdict(set)
    for entry in plan:
        clusters[entry["cluster_index"]].add(entry["host"])
    return clusters


def topology_with_cluster_count(cluster_type, count):
    """Write a temporary topology file with an overridden cluster count."""
    tmp = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
    data = json.loads(TOPOLOGY.read_text())
    data["cluster_types"][cluster_type]["count"] = count
    json.dump(data, tmp)
    tmp.close()
    return Path(tmp.name)


def run_start_at_hv_tests(vp):
    print("\n== start-at-hv placement ==")
    sections = vp.parse_inventory(INVENTORY)
    hvs = vp.parse_hv_hosts(sections)
    hv_count = len(hvs)

    def validate_cluster_local_rotation(cluster_type, cluster_count, start_at_hv, label):
        topo_path = topology_with_cluster_count(cluster_type, cluster_count)
        try:
            vm_types, cluster_types = vp.load_config(topo_path)
            plan = vp.build_deployment_plan(
                hvs,
                vm_types,
                cluster_types,
                [cluster_type],
                spread=False,
                start_at_hv=start_at_hv,
            )
            expected = expected_cluster_hosts(hvs, vp, cluster_count, start_at_hv)
            hosts_by_cluster = cluster_host_map(plan)
            ok = True
            details = []
            for cluster_index, expected_host in enumerate(expected, start=1):
                actual = hosts_by_cluster.get(cluster_index, set())
                if actual != {expected_host}:
                    ok = False
                    details.append(
                        f"cluster {cluster_index}: expected {expected_host.split('.')[0]}, got "
                        f"{sorted(h.split('.')[0] for h in actual)}"
                    )
            record(f"cluster-local rotation {label}", ok, "; ".join(details))
        finally:
            topo_path.unlink()

    validate_cluster_local_rotation("compact", 4, 0, "4 clusters from HV 0")
    validate_cluster_local_rotation("compact", 4, 2, "4 clusters from HV 2")
    validate_cluster_local_rotation("compact", 4, 4, "4 clusters from HV 4 with wrap")

    # spread: SNO uses per_hv=1, one VM per cluster on the rotated starting HV
    topo_path = topology_with_cluster_count("sno", 4)
    try:
        vm_types, cluster_types = vp.load_config(topo_path)
        plan = vp.build_deployment_plan(
            hvs,
            vm_types,
            cluster_types,
            ["sno"],
            spread=True,
            start_at_hv=2,
        )
        expected = expected_cluster_hosts(hvs, vp, 4, 2)
        hosts_by_cluster = cluster_host_map(plan)
        ok = all(
            hosts_by_cluster.get(i, set()) == {host}
            for i, host in enumerate(expected, start=1)
        )
        record("spread sno rotation from HV 2", ok, str({k: v for k, v in hosts_by_cluster.items()}))
    finally:
        topo_path.unlink()

    # offset should not place on skipped hypervisors when clusters fit without wrapping
    topo_path = topology_with_cluster_count("compact", 3)
    try:
        vm_types, cluster_types = vp.load_config(topo_path)
        plan = vp.build_deployment_plan(
            hvs, vm_types, cluster_types, ["compact"], spread=False, start_at_hv=2
        )
        skipped = {
            vp.ansible_host_for_hv(hvs[0]),
            vp.ansible_host_for_hv(hvs[1]),
        }
        used = {entry["host"] for entry in plan}
        record(
            "start-at-hv 2 skips first two hypervisors",
            not used & skipped,
            sorted(h.split(".")[0] for h in used),
        )
    finally:
        topo_path.unlink()

    # 12 standard clusters: compare default vs offset first and wrap-around cluster
    vm_types, cluster_types = vp.load_config(TOPOLOGY)
    plan_default = vp.build_deployment_plan(
        hvs, vm_types, cluster_types, ["standard"], spread=False, start_at_hv=0
    )
    plan_offset = vp.build_deployment_plan(
        hvs, vm_types, cluster_types, ["standard"], spread=False, start_at_hv=2
    )
    default_hosts = cluster_host_map(plan_default)
    offset_hosts = cluster_host_map(plan_offset)
    wrap_cluster = 7  # idx 6 -> HV index 0 with default, 2 with offset 2 on 6 HVs
    record(
        "12 standard offset shifts cluster 1 to HV 2",
        next(iter(offset_hosts[1])) == vp.ansible_host_for_hv(hvs[2]),
        f"cluster 1 -> {next(iter(offset_hosts[1])).split('.')[0]}",
    )
    record(
        "12 standard offset shifts wrap-around cluster 7",
        next(iter(default_hosts[wrap_cluster])) == vp.ansible_host_for_hv(hvs[(wrap_cluster - 1) % hv_count])
        and next(iter(offset_hosts[wrap_cluster])) == vp.ansible_host_for_hv(hvs[(wrap_cluster - 1 + 2) % hv_count]),
        (
            f"default={next(iter(default_hosts[wrap_cluster])).split('.')[0]} "
            f"offset={next(iter(offset_hosts[wrap_cluster])).split('.')[0]}"
        ),
    )

    # CLI dry-run surfaces the selected starting hypervisor
    result = run_cli(
        [
            "--dry-run",
            "--topology-file",
            str(TOPOLOGY),
            "--cluster-type",
            "compact",
            "--start-at-hv",
            "2",
        ]
    )
    record("cli dry-run start-at-hv exits 0", result.returncode == 0, result.stderr)
    record(
        "cli dry-run shows start-at-hv line",
        f"Start at HV    : 2 ({hvs[2]['hostname']})" in result.stdout,
        result.stdout.splitlines()[10:20] if result.stdout else "",
    )
    first_cluster_line = next(
        (line for line in result.stdout.splitlines() if line.startswith("  cluster 1 (compact)")),
        "",
    )
    record(
        "cli dry-run cluster 1 uses offset HV",
        hvs[2]["hostname"].split(".")[0] in result.stdout,
        first_cluster_line,
    )


def vm_lines_from_output(inventory_output):
    """Return VM host lines from flat or sub-group inventory output."""
    return [
        line
        for line in inventory_output.all_vm_lines()
        if line and not line.startswith("#")
    ]


def validate_generated_lines(vp, inventory_output, deployment_plan, vm_types, cluster_type):
    vm_lines = vm_lines_from_output(inventory_output)
    expected = expected_vm_count(vp, cluster_type)
    if not record("vm record count", len(vm_lines) == expected, f"{len(vm_lines)} != {expected}"):
        return False

    ok = True
    for line in vm_lines:
        fields = parse_vm_line(line)
        missing = REQUIRED_FIELDS - set(fields)
        if missing:
            record("required fields", False, f"{fields.get('name')}: missing {missing}")
            ok = False
            continue
        if not MAC_RE.match(fields["mac_address"]):
            record("mac format", False, fields["mac_address"])
            ok = False
        try:
            uuid.UUID(fields["domain_uuid"])
        except ValueError:
            record("uuid format", False, fields["domain_uuid"])
            ok = False
    if ok:
        record("required fields / mac / uuid on all VMs", True)
    return ok


def validate_cluster_local(vp, hvs, cluster_types, cluster_type):
    plan = vp.build_deployment_plan(
        hvs, vp.load_config(TOPOLOGY)[0], cluster_types, [cluster_type], spread=False
    )
    clusters = plan_cluster_hosts(plan)
    bad = {k: v for k, v in clusters.items() if len(v) > 1}
    record(
        f"cluster-local single HV per cluster ({cluster_type})",
        not bad,
        str(bad) if bad else "",
    )
    return plan


def validate_spread_uses_multiple_hvs(vp, hvs, cluster_types, cluster_type, min_hvs=3):
    plan = vp.build_deployment_plan(
        hvs, vp.load_config(TOPOLOGY)[0], cluster_types, [cluster_type], spread=True
    )
    hosts = {entry["host"] for entry in plan}
    record(
        f"spread uses >= {min_hvs} HVs ({cluster_type})",
        len(hosts) >= min_hvs,
        f"used {len(hosts)}: {sorted(h.split('.')[0] for h in hosts)}",
    )

    cluster_count = cluster_types[cluster_type]["count"]
    if cluster_count > 1:
        per_cluster_hosts = defaultdict(set)
        for entry in plan:
            per_cluster_hosts[entry["cluster_index"]].add(entry["host"])
        rotated = sum(1 for hosts_set in per_cluster_hosts.values() if len(hosts_set) > 1)
        record(
            f"spread multi-cluster uses >1 HV per cluster ({cluster_type})",
            rotated == cluster_count,
            f"{rotated}/{cluster_count} clusters spread",
        )
    return plan


def run_cluster_matrix(vp):
    print("\n== Cluster type matrix (6 HVs in test_cloud00.local) ==")
    vm_types, cluster_types = vp.load_config(TOPOLOGY)
    sections = vp.parse_inventory(INVENTORY)
    hvs = vp.parse_hv_hosts(sections)
    record("inventory has 6 hypervisors", len(hvs) == 6, str(len(hvs)))

    cases = [
        ("vmno", "below HV count (1 cluster)", False),
        ("compact", "below HV count (1 cluster)", False),
        ("standard", "exceeds HV count (12 clusters)", False),
        ("standard", "exceeds HV count (12 clusters)", True),
        ("crazy", "exceeds HV count (12 clusters)", False),
        ("crazy", "exceeds HV count (12 clusters)", True),
    ]

    for cluster_type, label, spread in cases:
        print(f"\n-- {cluster_type} / {label} / spread={spread} --")
        plan = (
            validate_spread_uses_multiple_hvs(vp, hvs, cluster_types, cluster_type)
            if spread
            else validate_cluster_local(vp, hvs, cluster_types, cluster_type)
        )
        inventory_output = vp.generate_inventory(
            plan,
            vp.vm_types_with_counts(
                vm_types, vp.aggregate_vm_counts(cluster_types, [cluster_type])
            ),
            network=vp.controlplane_network_from_sections(sections),
        )
        validate_generated_lines(vp, inventory_output, plan, vm_types, cluster_type)

    # matching HV count: 6 clusters on 6 HVs
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
        topo = json.loads(TOPOLOGY.read_text())
        topo["cluster_types"]["compact"]["count"] = 6
        json.dump(topo, tmp)
        topo_path = Path(tmp.name)

    try:
        print("\n-- compact x6 / matching HV count / cluster-local --")
        vm_types, cluster_types = vp.load_config(topo_path)
        plan = validate_cluster_local(vp, hvs, cluster_types, "compact")
        inventory_output = vp.generate_inventory(
            plan,
            vp.vm_types_with_counts(
                vm_types, vp.aggregate_vm_counts(cluster_types, ["compact"])
            ),
            network=vp.controlplane_network_from_sections(sections),
        )
        vm_lines = vm_lines_from_output(inventory_output)
        record("compact x6 vm record count", len(vm_lines) == 18, f"{len(vm_lines)} != 18")
        hosts_used = {entry["host"] for entry in plan}
        record(
            "matching HV count uses 6 distinct HVs",
            len(hosts_used) == 6,
            str(len(hosts_used)),
        )
        record(
            "compact x6 field validation",
            all(REQUIRED_FIELDS <= set(parse_vm_line(line)) for line in vm_lines),
        )
    finally:
        topo_path.unlink()

    # sno smaller sample
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as tmp:
        topo = json.loads(TOPOLOGY.read_text())
        topo["cluster_types"]["sno"]["count"] = 8
        json.dump(topo, tmp)
        topo_path = Path(tmp.name)

    try:
        print("\n-- sno x8 / exceeds HV count / cluster-local --")
        vm_types, cluster_types = vp.load_config(topo_path)
        plan = validate_cluster_local(vp, hvs, cluster_types, "sno")
        record("sno cluster count", len({e["cluster_index"] for e in plan}) == 8)
        names = []
        for entry in plan:
            for _ in range(entry["count"]):
                names.append(
                    vp.build_vm_name(entry, 1, 1, organize_vm_names=True, vm_prefix=None)
                )
        record(
            "sno organized names 1-8",
            sorted(names) == [f"sno-{i}" for i in range(1, 9)],
            str(sorted(names)[:5]),
        )
    finally:
        topo_path.unlink()


def run_cli_tests(vp):
    print("\n== CLI integration tests ==")

    topology_file_args = ["--topology-file", str(TOPOLOGY)]
    error_cases = [
        (
            "short without dry-run",
            [*topology_file_args, "--short", "--cluster-type", "vmno"],
            "--short requires --dry-run",
        ),
        (
            "short with assess-hv",
            [*topology_file_args, "--dry-run", "--short", "--assess-hv", "--cluster-type", "vmno"],
            "--short cannot be used with --assess-hv",
        ),
        (
            "multiple cluster types",
            [*topology_file_args, "--dry-run", "--cluster-type", "standard,sno"],
            "Only one cluster type",
        ),
        (
            "unknown cluster type",
            [*topology_file_args, "--dry-run", "--cluster-type", "nope"],
            "Unknown cluster type",
        ),
        (
            "missing topology",
            ["--dry-run", "--cluster-type", "vmno"],
            "topology.json",
        ),
        (
            "missing inventory",
            [*topology_file_args, "--dry-run", "--cluster-type", "vmno"],
            "Inventory file not found",
        ),
        (
            "start-at-hv below 0",
            [*topology_file_args, "--dry-run", "--cluster-type", "compact", "--start-at-hv", "-1"],
            "must be >= 0",
        ),
        (
            "start-at-hv exceeds hv count",
            [*topology_file_args, "--dry-run", "--cluster-type", "compact", "--start-at-hv", "6"],
            "exceeds hypervisor count",
        ),
    ]
    for name, args, needle in error_cases:
        if name == "missing topology" and vp.DEFAULT_TOPOLOGY_FILE.is_file():
            skip(name, "topology.json present")
            continue
        inv = Path("/no/such/file") if name == "missing inventory" else INVENTORY
        result = run_cli(args, inventory=inv)
        record(
            name,
            result.returncode != 0 and needle in result.stderr,
            result.stderr.strip() or result.stdout.strip(),
        )

    result = run_cli(["--dry-run"], inventory=INVENTORY)
    if vp.DEFAULT_TOPOLOGY_FILE.is_file():
        record("cli without topology-file exits 0", result.returncode == 0, result.stderr)
        record(
            "cli without topology-file uses default file",
            str(vp.DEFAULT_TOPOLOGY_FILE.resolve()) in result.stdout,
            result.stdout[:200] if result.stdout else result.stderr,
        )
    else:
        record(
            "cli without topology-file requires topology",
            result.returncode != 0 and "topology.json" in result.stderr,
            result.stderr.strip() or result.stdout.strip(),
        )

    base = [
        "--dry-run",
        "--topology-file",
        str(TOPOLOGY),
        "--cluster-type",
        "vmno",
    ]
    result = run_cli(base)
    record("dry-run vmno exits 0", result.returncode == 0, result.stderr)
    record(
        "dry-run includes summary",
        "VM Planner — dry run" in result.stdout and "[hv_vm] records" in result.stdout,
    )
    record(
        "dry-run includes HV distribution",
        "HV distribution" in result.stdout,
    )

    result = run_cli([*base, "--short"])
    record("short dry-run exits 0", result.returncode == 0, result.stderr)
    record(
        "short starts with [hv_vm]",
        result.stdout.startswith("[hv_vm]\n"),
        result.stdout.splitlines()[:2],
    )
    record(
        "short has no summary footer",
        "VM Planner" not in result.stdout and "No files were modified" not in result.stdout,
    )
    record(
        "short vmno count",
        sum(1 for line in result.stdout.splitlines() if " ansible_host=" in line) == 8,
    )

    result = run_cli([*base, "--spread"])
    record("dry-run spread exits 0", result.returncode == 0, result.stderr)
    record("spread dry-run labels spread", "HV distribution (spread)" in result.stdout)

    result = run_cli(
        [
            "--dry-run",
            "--topology-file",
            str(TOPOLOGY),
            "--cluster-type",
            "crazy",
            "--spread",
        ]
    )
    hosts = re.findall(r"^\s{4}\S+ \(\d+\.\d+\.\d+\.\d+\)", result.stdout, re.M)
    record(
        "crazy spread dry-run lists multiple HVs",
        len(set(hosts)) >= 4,
        f"unique host lines: {len(set(hosts))}",
    )

    result = run_cli(
        [
            "--dry-run",
            "--topology-file",
            str(TOPOLOGY),
            "--cluster-type",
            "standard",
            "--organize-vm-names",
        ]
    )
    record(
        "organize-vm-names produces cluster-* names",
        "cluster-1-master-1" in result.stdout,
    )

    result = run_cli(
        [
            "--dry-run",
            "--topology-file",
            str(TOPOLOGY),
            "--cluster-type",
            "vmno",
            "--vm-prefix",
            "node",
        ]
    )
    record("vm-prefix produces node* names", "node00001" in result.stdout)

    if shutil.which("sshpass"):
        result = run_cli(
            [
                "--dry-run",
                "--assess-hv",
                "--topology-file",
                str(TOPOLOGY),
                "--cluster-type",
                "compact",
            ]
        )
        if result.returncode == 0:
            record("assess-hv compact dry-run", "capacity:" in result.stdout or "planned:" in result.stdout)
        else:
            skip("assess-hv compact dry-run", result.stderr.strip())
    else:
        skip("assess-hv", "sshpass not installed")


def run_write_tests(vp):
    print("\n== File write tests (on inventory copy) ==")
    workdir = Path(tempfile.mkdtemp(prefix="vm-planner-test-"))
    inv_copy = workdir / "test_cloud00.local"
    shutil.copy(INVENTORY, inv_copy)

    try:
        args = [
            "--topology-file",
            str(TOPOLOGY),
            "--cluster-type",
            "compact",
        ]
        result = run_cli(args, inventory=inv_copy)
        out_file = workdir / "test_cloud00-1compact-3m.local"
        record("write derived file exits 0", result.returncode == 0, result.stderr)
        record("derived file created", out_file.is_file(), str(out_file))
        record("original unchanged", inv_copy.read_text() == INVENTORY.read_text())
        if out_file.is_file():
            content = out_file.read_text()
            record("[hv_vm] in derived file", "[hv_vm]" in content)
            record("3 vm records in compact", content.count(" ansible_host=") == 3)
            record("[hv_vm:vars] in derived file", "[hv_vm:vars]" in content)
            record(
                "hv_vm:vars has vm_cluster_count",
                "vm_cluster_count=1" in content,
            )
            record(
                "hv_vm:vars has vm_cluster_type_list",
                'vm_cluster_type_list=["compact"]' in content,
            )
            record(
                "hv_vm:vars has vm_cluster_list",
                'vm_cluster_list=["cluster1"]' in content,
            )
            record(
                "vm records include cluster assignment",
                "cluster=cluster1" in content,
            )

        # append more compact VMs to the same derived file
        result = run_cli(
            [
                "--topology-file",
                str(TOPOLOGY),
                "--cluster-type",
                "compact",
                "--append",
            ],
            inventory=inv_copy,
        )
        record("append to derived exits 0", result.returncode == 0, result.stderr)
        if out_file.is_file():
            appended = out_file.read_text()
            record(
                "append adds more compact VMs",
                appended.count(" ansible_host=") == 6,
                str(appended.count(" ansible_host=")),
            )

        # overwrite copy
        ow_copy = workdir / "test_cloud00-ow.local"
        shutil.copy(INVENTORY, ow_copy)
        result = run_cli(
            [
                "--topology-file",
                str(TOPOLOGY),
                "--cluster-type",
                "compact",
                "--overwrite-original",
            ],
            inventory=ow_copy,
        )
        record("overwrite-original exits 0", result.returncode == 0, result.stderr)
        ow_text = ow_copy.read_text()
        record("overwrite modifies file in place", ow_copy.stat().st_size != INVENTORY.stat().st_size)
        record("overwrite has compact VMs", ow_text.count(" ansible_host=") >= 3)
    finally:
        shutil.rmtree(workdir)


def run_memory_overcommit_tests(vp):
    print("\n== Memory overcommit write guard ==")
    if not shutil.which("sshpass"):
        skip("memory overcommit write guard", "sshpass not installed")
        return

    workdir = Path(tempfile.mkdtemp(prefix="vm-planner-mem-test-"))
    inv_copy = workdir / "test_cloud00.local"
    shutil.copy(INVENTORY, inv_copy)
    out_file = workdir / "test_cloud00-1compact-3m.local"

    def mock_capacity(ip, user, password, disk_paths, timeout=30):
        return {
            "cpus": 80,
            "memory": 64,
            "disk_by_path": {path: 1000 for path in disk_paths},
        }

    base_argv = [
        "vm-planner.py",
        "--inventory-file",
        str(inv_copy),
        "--topology-file",
        str(TOPOLOGY),
        "--cluster-type",
        "compact",
        "--assess-hv",
    ]

    try:
        with patch.object(vp, "fetch_hv_capacity", side_effect=mock_capacity):
            with patch.object(sys, "argv", base_argv):
                buffer = io.StringIO()
                with redirect_stdout(buffer):
                    result = vp.main()
                blocked_output = buffer.getvalue()
        record(
            "assess-hv blocks write on memory overcommit",
            result == 1
            and not out_file.is_file()
            and "MEMORY OVERCOMMIT DETECTED" in blocked_output
            and "INVENTORY FILE NOT CREATED" in blocked_output,
            blocked_output[-500:],
        )

        with patch.object(vp, "fetch_hv_capacity", side_effect=mock_capacity):
            with patch.object(sys, "argv", base_argv + ["--force"]):
                buffer = io.StringIO()
                with redirect_stdout(buffer):
                    result = vp.main()
                forced_output = buffer.getvalue()
        record(
            "assess-hv --force writes file despite memory overcommit",
            result == 0
            and out_file.is_file()
            and "--force was used" in forced_output
            and "not recommended" in forced_output.lower(),
            forced_output[-500:],
        )
    finally:
        shutil.rmtree(workdir)


def verify_backup_restorable():
    print("\n== Backup integrity ==")
    record(
        "backup matches original snapshot",
        BACKUP.read_text() == INVENTORY.read_text(),
    )


def main():
    print("vm-planner extensive test suite")
    print(f"Inventory: {INVENTORY}")
    print(f"Topology:  {TOPOLOGY}")
    print(f"Backup:    {BACKUP}")

    vp = load_module()
    run_internal_tests(vp)
    run_start_at_hv_tests(vp)
    run_cluster_matrix(vp)
    run_cli_tests(vp)
    run_write_tests(vp)
    run_memory_overcommit_tests(vp)
    verify_backup_restorable()

    print("\n" + "=" * 60)
    print(f"Results: {passed} passed, {failed} failed, {skipped} skipped")
    if failures:
        print("\nFailures:")
        for item in failures:
            print(item)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
