# ARCHITECTURE.md

This document provides a comprehensive architectural overview of Jetlag, explaining system components, deployment flows, and technical design decisions.

## Table of Contents

- [System Overview](#system-overview)
- [Deployment Architectures](#deployment-architectures)
- [Component Architecture](#component-architecture)
- [Network Architecture](#network-architecture)
- [Storage Architecture](#storage-architecture)
- [VM and Hypervisor Architecture](#vm-and-hypervisor-architecture)
- [Deployment Workflow](#deployment-workflow)
- [Data Flow Diagrams](#data-flow-diagrams)
- [API Interactions](#api-interactions)
- [Design Decisions](#design-decisions)

## System Overview

### What is Jetlag?

Jetlag is an Ansible-based automation framework for deploying OpenShift clusters via the Assisted Installer in bare metal environments. It orchestrates the entire cluster lifecycle from bastion setup to cluster installation, supporting:

- **Red Hat Performance Lab** (Dell r750, 740xd hardware)
- **Red Hat Scale Lab** (Dell r750/r660/r650/r640/r630/fc640, Supermicro systems)
- **IBMcloud Bare Metal** (Supermicro E5-2620, Lenovo SR630)

### Core Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Jetlag Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Ansible    │  │   Bastion    │  │  Bare Metal  │     │
│  │ Playbooks &  │─▶│   Machine    │─▶│   Cluster    │     │
│  │    Roles     │  │  (Services)  │  │    Nodes     │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│         │                  │                  │            │
│         │                  │                  │            │
│         ▼                  ▼                  ▼            │
│  Configuration      Assisted Installer   Discovery ISO    │
│  Management         DNS/DHCP/Registry     Boot Process    │
│  Inventory Gen      HAProxy/HTTP          Installation    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Idempotent Operations**: All playbooks safe to re-run
2. **Modular Architecture**: Roles encapsulate specific functionality
3. **Environment Agnostic**: Works across multiple lab environments
4. **Hardware Abstraction**: Hardware definitions centralized in `lab.yml`
5. **Declarative Configuration**: Users define desired state in `all.yml
│  │  │  └────────┘ └────────┘ └────────┘                           │ │ │
│  │  │                                                               │ │ │
│  │  │  Services:                                                   │ │ │
│  │  │  • libvirt/QEMU                                             │ │ │
│  │  │  • sushy-tools (Redfish BMC emulation)                      │ │ │
│  │  │  • DNSMasq (VM DHCP/DNS)                                    │ │ │
│  │  │  • Metrics Exporter (Optional)                              │ │ │
│  │  └──────────────────────────────────────────────────────────────┘ │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                  BMC/Management Network                           │ │
│  │  iDRAC/BMC connections for power control & virtual media         │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

## System Components

### Bastion Machine

The bastion is the first machine in any lab allocation and serves as the orchestration and service hub.

**Critical Services:**

1. **Assisted Installer (v2.x)**
   - Containerized service managing cluster lifecycle
   - REST API on port 8090
   - PostgreSQL database for state management
   - Integrates with Discovery ISO generation

2. **Assisted Image Service**
   - Generates customized discovery ISOs
   - Port 8888 for ISO requests
   - Embeds ignition configs and network settings

3. **DNS Services** (DNSMasq or CoreDNS)
   - Authoritative DNS for cluster domains
   - DHCP for controlplane network (optional)
   - Static IP assignment via reservations
   - Upstream DNS forwarding

4. **HTTP Server** (Python SimpleHTTPServer or Nginx)
   - Serves discovery ISO files
   - Hosts ignition configs
   - Provides installation artifacts

5. **Container Registry** (Optional, based on `setup_bastion_registry`)
   - Local mirror of OCP release images
   - Operator catalog mirrors
   - Reduces external bandwidth requirements
   - Supports disconnected installations

6. **Object Storage** (Optional, RustFS-based S3-compatible)
   - S3-compatible storage for image-based installations
   - Default bucket creation (e.g., `ibu` for Image-Based Upgrade)
   - Web console on port 9001, API on port 9000

7. **HAProxy** (Optional, for cluster access)
   - Proxies API server (port 6443)
   - Proxies ingress (ports 80/443)
   - Required for private IPv4 networks or disconnected IPv6 clusters

8. **Proxy Server** (Optional, Squid)
   - HTTP/HTTPS proxy for outbound connections
   - Required for disconnected environments with limited external access

**Network Roles:**
- Management network gateway to BMC/iDRAC interfaces
- Router and DNS for controlplane network
- NAT gateway for cluster internet access (connected deployments)

### Cluster Nodes

**Control-Plane Nodes (Masters)**
- Minimum 3 nodes for HA (MNO)
- Run etcd, API server, scheduler, controller-manager
- Can be schedulable (compact cluster with `worker_node_count: 0`)
- Installed via Discovery ISO boot process

**Worker Nodes**
- Variable count based on `worker_node_count`
- Optional for MNO (compact cluster if count=0)
- Can be bare metal or virtual (hybrid via `hybrid_worker_count`)
- Joined post-control-plane initialization

**SNO Nodes**
- Single node combining master + worker roles
- One cluster per available machine after bastion
- Minimal resource requirements
- Ideal for edge/far-edge deployments

### Hypervisor Nodes

Unused machines in MNO allocations become hypervisors for additional cluster deployments.

**Capabilities:**
- KVM/libvirt virtualization
- Bridged networking to controlplane VLAN
- Sushy-tools for Redfish BMC emulation
- Static DHCP assignments via DNSMasq
- Supports SNO, compact (3-node), standard, and jumbo cluster VMs

**VM Resource Defaults:**
- 8 vCPUs
- 18 GiB Memory
- 120 GB Disk
- Configurable per hardware type in `vars/lab.yml`

## Architecture Layers

### 1. Inventory Generation Layer

**Purpose:** Dynamically generate Ansible inventory from lab allocation metadata.

**Components:**
- `create-inventory` role
- Lab API integrations (QUADS for Scale Lab, IBMcloud CLI)
- Hardware detection and NIC/disk discovery

**Process:**
1. Query lab allocation API
2. Identify bastion (first machine)
3. Classify remaining machines based on `cluster_type`:
   - MNO: 3 control-plane + N workers + remaining as HVs
   - SNO: Each machine becomes an SNO cluster
4. Determine network interfaces via lab metadata
5. Generate `ansible/inventory/<cloud>.local` file

**Inventory Structure:**
```ini
[bastion]
bastion.example.com

[controlplane]
control-plane-0 ip=198.18.0.5 mac_address=... bmc_address=...
control-plane-1 ip=198.18.0.6 ...
control-plane-2 ip=198.18.0.7 ...

[worker]
worker-0 ip=198.18.0.8 ...
worker-1 ip=198.18.0.9 ...

[hv]
hv-0.example.com bmc_address=... vendor=Dell
hv-1.example.com ...
```

### 2. Bastion Configuration Layer

**Purpose:** Transform bastion into a fully-functional deployment hub.

**Playbook:** `setup-bastion.yml`

**Role Execution Order:**
1. **validate-vars**: Pre-flight checks on configuration
2. **ocp-release**: Determine OCP version metadata
3. **bastion-install**: System packages, firewall, SELinux
4. **bastion-network**: Configure interfaces, routing, IP forwarding
5. **bastion-data-disk**: Optional dedicated data disk setup
6. **bastion-dnsmasq** / **bastion-coredns**: DNS/DHCP services
7. **bastion-http**: HTTP server for ISO/ignition serving
8. **bastion-ocp-version**: Fetch OCP release metadata
9. **bastion-registry** (conditional): Mirror registry setup
10. **sync-operator-index** (conditional): Operator catalog mirroring
11. **sync-ocp-release** (conditional): OCP image mirroring
12. **bastion-proxy** (conditional): Squid proxy deployment
13. **bastion-assisted-installer**: Deploy Assisted Installer containers
14. **bastion-gogs** (conditional): Git server deployment
15. **bastion-haproxy** (conditional): API/Console proxy
16. **hv-metrics-server** (conditional): Metrics collection setup
17. **bastion-object-store** (conditional): RustFS S3 deployment

**Configuration Persistence:**
- Systemd unit files for containerized services
- Firewall rules for required ports
- DNS zone files and DHCP reservations
- Registry storage and pull-through cache configs

### 3. Cluster Deployment Layer

**Purpose:** Deploy OpenShift clusters using Assisted Installer.

**MNO Playbook:** `mno-deploy.yml`

**Role Execution Order:**
1. **validate-vars**: Verify MNO-specific configuration
2. **ocp-release**: Resolve OCP version to deploy
3. **create-ai-cluster**: Create cluster definition via Assisted Installer API
4. **generate-discovery-iso**: Request ISO with cluster UUID
5. **boot-iso** (controlplane): Boot control-plane nodes with discovery ISO
6. **boot-iso** (worker): Boot worker nodes with discovery ISO
7. **wait-hosts-discovered**: Poll until all nodes register with Assisted Installer
8. **configure-local-storage**: Apply LSO configurations (if enabled)
9. **install-cluster**: Trigger installation via Assisted Installer API
10. **mno-post-cluster-install**: Post-install tasks (ODF, storage classes, etc.)

**SNO Playbook:** `sno-deploy.yml`

Simplified workflow creating one cluster per machine in parallel.

### 4. Post-Deployment Layer

**Purpose:** Configure cluster services and integrations after installation.

**MNO Post-Install Tasks:**
- Configure Local Storage Operator (LSO)
- Deploy OpenShift Data Foundation (ODF) if `setup_odf: true`
- Set default storage class
- Configure MetalLB (if enabled)
- Apply cluster customizations

**SNO Post-Install Tasks:**
- Configure LSO per SNO cluster
- Apply cluster-specific configurations
- Generate kubeconfig files per cluster

## Deployment Workflows

### MNO Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Inventory Generation                                                 │
│    create-inventory.yml                                                 │
│    └─> Generates ansible/inventory/<cloud>.local                       │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 2. Bastion Setup                                                        │
│    setup-bastion.yml -i inventory/<cloud>.local                        │
│    ├─> Install system packages & configure firewall                   │
│    ├─> Configure networking & DNS                                     │
│    ├─> Deploy Assisted Installer (Podman containers)                  │
│    ├─> Setup optional services (registry, proxy, object storage)      │
│    └─> Verify services are running                                    │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 3. Cluster Deployment                                                   │
│    mno-deploy.yml -i inventory/<cloud>.local                           │
│    ├─> Create cluster in Assisted Installer                           │
│    ├─> Generate discovery ISO with cluster UUID                       │
│    ├─> Boot control-plane nodes (via Redfish virtual media)           │
│    ├─> Boot worker nodes (via Redfish virtual media)                  │
│    ├─> Wait for nodes to be discovered                                │
│    ├─> Assisted Installer validates & installs cluster                │
│    └─> Post-install configuration (LSO, ODF, storage class)           │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 4. Cluster Ready                                                        │
│    Kubeconfig: /root/mno/kubeconfig                                    │
│    Admin Password: /root/mno/kubeadmin-password                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### SNO Deployment Flow

Similar to MNO but parallelized per machine, creating one SNO cluster per available hardware resource after the bastion.

### VMNO Deployment Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Inventory Generation (cluster_type: vmno)                           │
│    create-inventory.yml                                                 │
│    └─> Allocates HV nodes, generates VM entries                       │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 2. Bastion Setup                                                        │
│    setup-bastion.yml                                                   │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 3. Hypervisor Setup                                                     │
│    hv-setup.yml -i inventory/<cloud>.local                             │
│    ├─> Configure libvirt/KVM                                          │
│    ├─> Setup bridged networking                                       │
│    ├─> Deploy sushy-tools (Redfish emulator)                          │
│    └─> Configure VM DHCP (optional)                                   │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 4. VM Creation                                                          │
│    hv-vm-create.yml -i inventory/<cloud>.local                         │
│    ├─> Create VM definitions (XML)                                    │
│    ├─> Allocate VM disks                                              │
│    ├─> Start VMs                                                      │
│    └─> Generate manifests for ACM/MCE (optional)                      │
└────────────────────────┬────────────────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────────────────┐
│ 5. Cluster Deployment                                                   │
│    mno-deploy.yml -i inventory/<cloud>.local                           │
│    └─> Deploys OCP to VMs via Assisted Installer                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## Ansible Role Organization

Jetlag uses a modular role architecture with clear separation of concerns.

### Bastion Roles

**Infrastructure Roles:**
- `bastion-install`: Base system configuration, packages, firewall
- `bastion-network`: Network interfaces, routing, IP forwarding
- `bastion-data-disk`: Optional dedicated data disk mounting

**Service Roles:**
- `bastion-dnsmasq`: DNSMasq for DNS/DHCP
- `bastion-coredns`: CoreDNS alternative to DNSMasq
- `bastion-http`: HTTP server for ISO/config serving
- `bastion-assisted-installer`: Deploy Assisted Installer stack
- `bastion-registry`: Local container registry + mirroring
- `bastion-proxy`: Squid proxy for disconnected environments
- `bastion-haproxy`: HAProxy for cluster API/Console access
- `bastion-object-store`: RustFS S3-compatible object storage
- `bastion-gogs`: Git server for GitOps workflows

**Support Roles:**
- `bastion-ocp-version`: Resolve OCP version metadata
- `bastion-dnsmasq-clean`: Clean DNSMasq state between deployments
- `bastion-object-store-clean`: Reset object storage buckets

### Installation Roles

- `create-ai-cluster`: Interact with Assisted Installer API to create cluster
- `generate-discovery-iso`: Request and download discovery ISO
- `boot-iso`: Redfish-based virtual media boot orchestration
- `wait-hosts-discovered`: Poll Assisted Installer for host registration
- `configure-local-storage`: Apply LSO (Local Storage Operator) configs
- `install-cluster`: Trigger cluster installation via API
- `mno-post-cluster-install`: Post-install configuration for MNO
- `sno-post-cluster-install`: Post-install configuration for SNO

### Hypervisor Roles

**Setup Roles:**
- `hv-install`: Base HV system configuration
- `hv-network`: Bridge and network configuration
- `hv-libvirt`: Libvirt/KVM setup
- `hv-dnsmasq` / `hv-coredns`: VM DNS/DHCP services
- `hv-setup-disk2`: Multi-disk configuration for VMs

**VM Management Roles:**
- `hv-vm-create`: Create and start VMs
- `hv-vm-delete`: Delete VMs and cleanup
- `hv-vm-manifests-sno`: Generate SNO manifests for ACM
- `hv-vm-manifests-compact`: Generate 3-node cluster manifests
- `hv-vm-manifests-standard`: Generate multi-node cluster manifests
- `hv-vm-manifests-jumbo`: Generate large cluster manifests

**Monitoring Roles:**
- `hv-metrics-exporter`: Prometheus exporter per HV
- `hv-metrics-server`: Central Prometheus + Grafana on bastion

### Utility Roles

- `validate-vars`: Pre-flight configuration validation
- `create-inventory`: Dynamic inventory generation from lab APIs
- `ibmcloud-create-inventory`: IBMcloud-specific inventory generation
- `ocp-release`: OCP version resolution and metadata fetching
- `sync-ocp-release`: Mirror OCP release images to bastion registry
- `sync-operator-index`: Mirror operator catalogs
- `sync-acm-d`: Mirror ACM/MCE images
- `sync-mcgh`: Mirror Multicluster Global Hub images
- `badfish`: Dell iDRAC boot order management
- `install-tc`: Traffic control for network impairments
- `ocp-scale-out`: Add nodes to existing MNO cluster
- `ocp-scale-out-csr`: Approve pending CSRs during scale-out
- `mno-add-bmc`: Add BMC credentials post-deployment

## Network Architecture

### Network Segmentation

**Management Network (Lab VLAN):**
- BMC/iDRAC interfaces for out-of-band management
- SSH access to bastion, HVs
- Bastion's lab interface participates

**Controlplane Network (e.g., 198.18.0.0/16):**
- OCP cluster communication
- API server, etcd, pod networking
- Bastion acts as gateway/router
- Static IP assignments via DNS/DHCP

**Optional Public VLAN:**
- Direct internet-routable IPs for clusters
- Bypasses bastion NAT
- Enabled via `public_vlan: true`

### DNS Resolution Flow

```
┌──────────────┐
│  OCP Node    │
│  (Worker)    │
└──────┬───────┘
       │ DNS query for api.cluster.example.com
       ▼
┌──────────────┐
│  Bastion     │
│  DNSMasq     │
│  (198.18.0.1)│
└──────┬───────┘
       │
       ├─> Cluster zone? → Return cluster API VIP
       │
       └─> External domain? → Forward to upstream DNS (10.1.36.1)
```

### Network Connectivity Patterns

**Connected Deployment:**
- Bastion provides NAT for cluster nodes
- Direct internet access for pulling images
- Optional bastion registry for caching

**Disconnected Deployment:**
- Bastion registry required (`use_bastion_registry: true`)
- All images mirrored to bastion
- No external connectivity from cluster nodes
- Bastion proxy (Squid) for selective external access

**Disconnected IPv6 with HAProxy:**
- HAProxy proxies cluster API (port 6443) and console (ports 80/443)
- Laptop configures `/etc/hosts` to point to bastion IP
- Access `https://api.cluster.example.com:6443` via bastion

## Data Flow

### Cluster Creation Flow

```
┌──────────────┐         ┌──────────────────┐
│   Ansible    │  POST   │  Assisted        │
│   Playbook   ├────────>│  Installer API   │
│              │         │  (port 8090)     │
└──────────────┘         └────────┬─────────┘
                                  │
                                  │ Create cluster UUID
                                  ▼
                         ┌────────────────────┐
                         │  PostgreSQL DB     │
                         │  (cluster state)   │
                         └────────────────────┘
```

### Image Discovery and Boot Flow

```
┌──────────────┐         ┌──────────────────┐        ┌──────────────┐
│   Ansible    │ Request │  Assisted Image  │        │  HTTP Server │
│   Playbook   ├────────>│  Service (8888)  ├───────>│  (port 8080) │
│              │         │                  │  ISO   │              │
└──────────────┘         └──────────────────┘        └──────┬───────┘
                                                             │
                                ┌────────────────────────────┘
                                │
                                ▼
                         ┌─────────────┐
                         │  Bare Metal │
                         │  Node BMC   │<─── Redfish virtual media mount
                         │  (iDRAC)    │
                         └──────┬──────┘
                                │
                                │ Boot from ISO
                                ▼
                         ┌─────────────┐
                         │  Discovery  │
                         │  Agent      │───> Register with Assisted Installer
                         └─────────────┘
```

### Installation Progress Flow

```
┌─────────────┐
│  Assisted   │
│  Installer  │
└──────┬──────┘
       │
       │ 1. Validate hardware inventory
       │
       │ 2. Generate ignition configs
       │
       │ 3. Trigger node installations
       │
       ▼
┌─────────────┐         ┌─────────────┐
│  Master-0   │         │  Master-1   │  ... Master-2
│             │  etcd   │             │
│  Bootstrap  │<───────>│  Cluster    │
│  Control    │         │             │
└──────┬──────┘         └─────────────┘
       │
       │ 4. Wait for cluster operators
       │
       │ 5. Add worker nodes
       │
       ▼
┌─────────────┐
│  Cluster    │
│  Ready      │
└─────────────┘
```

## Storage Architecture

**Local Storage Operator (LSO):**
- Provisions local volumes on control-plane and worker nodes
- Supports LVM-based volumes (`localvolume-lvm`)
- Supports raw block devices (`localvolume-disk`)
- Configured via `lso_disks`, `lso_device_paths`, `lso_lv_*` variables
- Ignition handles disk wiping, partitioning, LVM setup at first boot

**OpenShift Data Foundation (ODF):**
- Ceph-backed block, file, and object storage
- Requires 3+ worker nodes with dedicated disks
- Enabled via `setup_odf: true`
- Configured via `odf_*` variables (device paths, replica count, etc.)

**Default Storage Class:**
- Automatically set based on configuration:
  - ODF enabled → `ocs-storagecluster-cephfs` (RWX-capable)
  - LSO with LVM → `localstorage-sc`
  - LSO with disks → `localstorage-disk-sc`
- Override with `default_storage_class` variable
- Disable automation with `set_default_storage_class: false`

**Bastion Object Storage (RustFS):**
- S3-compatible object storage on bastion
- Used for image-based installations (Image-Based Install operator)
- Creates default buckets (e.g., `ibu` for Image-Based Upgrade)
- Web console on port 9001, S3 API on port 9000
- Lightweight Rust-based alternative to MinIO

## Technology Stack

**Core Technologies:**
- **Ansible (4.10+)**: Orchestration and automation
- **Python (3.x)**: Ansible dependencies, utility scripts
- **Podman (3/4)**: Container runtime for bastion services
- **RHEL (>= 9.4)**: Base OS for bastion and hypervisors

**OpenShift Components:**
- **Assisted Installer (v2.x)**: Cluster lifecycle management
- **OpenShift Container Platform**: Kubernetes distribution
- **Local Storage Operator**: Local volume provisioning
- **OpenShift Data Foundation**: Ceph storage solution

**Infrastructure Services:**
- **DNSMasq / CoreDNS**: DNS and DHCP
- **Nginx / Python HTTP Server**: File serving
- **PostgreSQL**: Assisted Installer database
- **RustFS**: S3-compatible object storage
- **Squid**: HTTP proxy
- **HAProxy**: Load balancing and proxying

**Virtualization:**
- **libvirt**: VM management
- **QEMU/KVM**: Hypervisor
- **sushy-tools**: Redfish BMC emulation for VMs

**Monitoring (Optional):**
- **Prometheus**: Metrics collection
- **Grafana**: Metrics visualization
- **Node Exporter**: System metrics

**Lab Integration:**
- **QUADS API**: Scale Lab allocation management
- **IBMcloud CLI**: IBMcloud bare metal provisioning
- **Redfish/iDRAC**: BMC interaction for power and boot control

## Design Principles

**1. Infrastructure as Code**
- All configurations defined in Git-trackable YAML
- Reproducible deployments across environments
- Version-controlled lab definitions

**2. Modularity**
- Roles are single-purpose and composable
- Optional features controlled via variables
- Easy to extend or replace components

**3. Idempotency**
- Playbooks can be re-run safely
- State is declarative, not imperative
- Failed runs can be resumed

**4. Lab Agnostic**
- Abstract hardware differences via inventory
- Support multiple lab environments (Scale, Performance, IBMcloud)
- Hardware-specific logic isolated in `vars/lab.yml`

**5. Disconnected-First**
- Support for air-gapped deployments
- Registry mirroring capabilities
- Proxy support for selective external access

**6. Automation Over Manual Steps**
- Redfish-based power and boot control
- Automated BMC credential management
- Self-service cluster deployments

**7. Extensibility**
- Clear role boundaries for custom additions
- Hooks for post-deployment customization
- Support for custom CatalogSources and operators

## Extension Points

**Custom Operators:**
- Place custom CatalogSource definitions in `extra-manifests/` directory
- Automatically applied during cluster installation

**Post-Deployment Hooks:**
- Add custom tasks to `*-post-cluster-install` roles
- Example: Applying custom policies, installing additional operators

**Custom Hardware:**
- Add hardware definitions to `vars/lab.yml`
- Define NIC names, disk paths, VM counts per type

**Network Customizations:**
- Override `cluster_network`, `service_network`, `machine_network`
- Customize interface selection via `bastion_*_interface` variables

**Alternative DNS/DHCP:**
- Choose between DNSMasq and CoreDNS via `setup_coredns`
- Disable DHCP with `setup_hv_vm_dhcp: false`

**Storage Backends:**
- Toggle LSO, ODF independently
- Customize storage class defaults
- Add custom LocalVolume or StorageClass definitions

**Metrics and Monitoring:**
- Enable HV metrics with `setup_hv_metrics: true`
- Access Grafana dashboards on bastion
- Add custom Prometheus exporters

---

**Contributing:** See repository CONTRIBUTING guidelines for extending this architecture.

**Related Documents:**
- [README.md](README.md) - Quick start and usage
- [CLAUDE.md](CLAUDE.md) - Project documentation for AI assistance
- [docs/](docs/) - Detailed guides for specific scenarios
