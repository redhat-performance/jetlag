# HV Metrics

Jetlag can deploy a Prometheus and Grafana monitoring stack on the bastion to collect system metrics from hypervisor nodes and the bastion machine itself. This is useful for observing resource consumption during test runs, including CPU, memory, disk I/O, network bandwidth, and per-service traffic such as the mirror registry.

_**Table of Contents**_

<!-- TOC -->
- [HV Metrics](#hv-metrics)
  - [Architecture](#architecture)
  - [Variables](#variables)
  - [Enabling HV Metrics](#enabling-hv-metrics)
  - [Accessing the Dashboards](#accessing-the-dashboards)
  - [Dashboards](#dashboards)
  - [Registry Traffic Monitoring](#registry-traffic-monitoring)
  - [Resetting Registry Traffic Counters](#resetting-registry-traffic-counters)
<!-- /TOC -->

## Architecture

The monitoring stack consists of two components:

| Component | Deployed On | Description |
| --------- | ----------- | ----------- |
| **hv-metrics-server** | Bastion | Podman pod with Prometheus, Grafana, and a node-exporter container for bastion system metrics |
| **hv-metrics-exporter** | Each hypervisor | Prometheus node-exporter container exposing system metrics on port 9100 |

Prometheus on the bastion scrapes node-exporter instances on each hypervisor and the bastion's own node-exporter. Grafana provides pre-built dashboards for visualizing the collected data. All dashboards default to UTC timezone.

When `setup_bastion_registry` is also enabled, a systemd timer collects registry-specific metrics (network traffic via iptables accounting, container CPU/memory via cgroup, and active connections) and exposes them through the bastion's node-exporter textfile collector.

## Variables

### Server variables

Defined in `ansible/roles/hv-metrics-server/defaults/main/main.yaml`. Override in the `Extra vars` section of `ansible/vars/all.yml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `setup_hv_metrics` | `false` | Enable the HV metrics stack (set in `all.yml` and/or `hv.yml`) |
| `hv_metrics_server_deploy_grafana` | `true` | Deploy Grafana alongside Prometheus |
| `hv_metrics_server_grafana_username` | `testadmin` | Grafana admin username |
| `hv_metrics_server_grafana_password` | `testadmin` | Grafana admin password |
| `hv_metrics_server_scrape_interval` | `15s` | Prometheus scrape interval |
| `hv_metrics_server_retention_time` | `14d` | Prometheus data retention period |
| `hv_metrics_server_enable_bastion_exporter` | `true` | Deploy a node-exporter in the metrics pod for bastion system metrics |
| `hv_metrics_server_enable_local_prometheus` | `true` | Scrape Prometheus's own metrics |

### Exporter variables

Defined in `ansible/roles/hv-metrics-exporter/defaults/main.yaml`.

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `hv_metrics_exporter_container_name` | `hv-metrics-exporter` | Node-exporter container name on hypervisors |
| `hv_metrics_exporter_container_image` | `quay.io/prometheus/node-exporter:latest` | Node-exporter container image |

## Enabling HV Metrics

### 1. Set variables

In `ansible/vars/all.yml`, enable hv-metrics in the `Extra vars` section:

```yaml
################################################################################
# Extra vars
################################################################################
setup_hv_metrics: true
```

If deploying hypervisors, also set the same variable in `ansible/vars/hv.yml`:

```yaml
setup_hv_metrics: true
```

### 2. Run the playbooks

The hv-metrics-server role runs as part of the bastion setup:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
```

The hv-metrics-exporter role runs as part of the hypervisor setup:

```console
[root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml
```

## Accessing the Dashboards

Once deployed, the following endpoints are available on the bastion:

| Endpoint | Port | Description |
| -------- | ---- | ----------- |
| Grafana | 3000 | Dashboard UI (login: `testadmin` / `testadmin`) |
| Prometheus | 9090 | Prometheus query UI and targets page |
| Node-exporter (bastion) | 9100 | Bastion system metrics endpoint |

Access Grafana at `http://<bastion>:3000`. Verify all scrape targets are healthy at `http://<bastion>:9090/targets`.

## Dashboards

Two pre-built dashboards are provisioned. Both share a consistent layout for system metrics.

### Hypervisors Dashboard

Monitors hypervisor nodes with panels for:

- **CPU**: Utilization (%), cores used, load averages (1m/5m/15m)
- **Memory**: Utilization (%), memory used
- **Disk Space**: Root filesystem used, root usage gauge (%), all mountpoints
- **Disk I/O**: IOPS, throughput, I/O utilization (%) — selectable via **Disk Device** dropdown
- **Network**: All physical interface bandwidth, received/transmitted breakdown (collapsed by default) — selectable via **Network Interface** dropdown

Use the **Job Selection** dropdown to filter by specific hypervisors. Bastion machine is excluded from this dashboard.

### Bastion Dashboard

Monitors the bastion machine with panels for:

- **CPU**: Utilization (%), cores used (with total cores reference line), load averages
- **Memory**: Utilization (%), memory used (with total memory reference line)
- **Disk Space**: Root filesystem used, root usage gauge (%), all mountpoints
- **Disk I/O**: IOPS, throughput, I/O utilization (%) — selectable via **Disk Device** dropdown
- **Network**: All physical interface bandwidth, received/transmitted breakdown — selectable via **Network Interface** dropdown
- **Mirror Registry**: Container CPU usage (cores), container memory (working set and total), active connections, bandwidth, throughput, cumulative bytes transferred, and packets/s (only populated when `setup_bastion_registry` is enabled)

> [!NOTE]
> Registry bandwidth (measured via iptables at the IP layer) may appear 5-10% higher than the NIC-level bandwidth shown in the Network section. This is expected — iptables counts TCP/IP headers that are not included in the interface byte counters. The NIC graph reflects true wire bandwidth.

## Registry Traffic Monitoring

When `setup_bastion_registry` is `true`, the hv-metrics-server role automatically deploys registry traffic monitoring:

1. **iptables accounting rules** are created for TCP traffic on the registry port (default: 5000), covering both IPv4 and IPv6
2. **A collector script** (`/root/hv-metrics/registry-traffic-collector.sh`) reads iptables byte/packet counters, container CPU/memory from cgroup files, and active connection count via `ss`
3. **A systemd timer** (`registry-traffic-collector.timer`) runs the collector every 5 seconds
4. **Node-exporter** serves the metrics via its textfile collector, making them available to Prometheus

The following metrics are exposed:

| Metric | Type | Description |
| ------ | ---- | ----------- |
| `registry_network_receive_bytes_total` | counter | Bytes received by the registry (pull requests in) |
| `registry_network_transmit_bytes_total` | counter | Bytes transmitted by the registry (image data out) |
| `registry_network_receive_packets_total` | counter | Packets received by the registry |
| `registry_network_transmit_packets_total` | counter | Packets transmitted by the registry |
| `registry_container_cpu_usage_seconds_total` | counter | Cumulative CPU time consumed by the registry container |
| `registry_container_memory_usage_bytes` | gauge | Total memory charged to the registry container cgroup (includes reclaimable page cache) |
| `registry_container_memory_working_set_bytes` | gauge | Working set memory of the registry container (`memory.current - inactive_file`) |
| `registry_container_memory_limit_bytes` | gauge | Memory limit of the registry container (0 if unlimited) |
| `registry_network_connections` | gauge | Current number of established connections to the registry |

### Registry Memory Metrics

The dashboard shows two memory series for the registry container:

- **working set** — `memory.current - inactive_file` from the container's cgroup. This is the same calculation that `podman stats` and `docker stats` use ([containers/common#2454](https://github.com/containers/common/issues/2454)). It excludes inactive file-backed page cache that the kernel can reclaim under memory pressure.
- **total (incl. page cache)** — the raw `memory.current` value from the cgroup. This includes all memory charged to the container, including reclaimable page cache from serving container images. This value can appear significantly higher than actual memory consumption (e.g. 75 GiB vs 1 GiB) on systems with large registries.

Both values will differ from `top` RES for the registry process. `top` shows per-process resident pages (anonymous + file-mapped memory), while the cgroup metrics include kernel memory charged to the container (slab, socket buffers, etc.) that doesn't appear in any single process's RSS.

## Resetting Registry Traffic Counters

The iptables counters accumulate from when the rules were created and reset on reboot. To manually reset the counters without rebooting:

```console
[root@<bastion> ~]# iptables -Z REGISTRY_RX
[root@<bastion> ~]# iptables -Z REGISTRY_TX
[root@<bastion> ~]# ip6tables -Z REGISTRY_RX
[root@<bastion> ~]# ip6tables -Z REGISTRY_TX
```

The `-Z` flag zeros the packet and byte counters on the specified chains without affecting any other iptables rules.
