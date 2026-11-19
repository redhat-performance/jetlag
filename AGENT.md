# AGENT.md

This file provides development-focused guidance for AI agents working with the Jetlag codebase. For user-facing documentation and deployment instructions, see [CLAUDE.md](CLAUDE.md).

## Repository Structure

### Top-Level Organization
```
jetlag/
├── ansible/                 # All Ansible automation
│   ├── roles/              # Ansible roles (modular units of work)
│   ├── vars/               # Variable files and samples
│   ├── inventory/          # Generated and sample inventory files
│   ├── *.yml               # Top-level playbooks
│   └── templates/          # Jinja2 templates for config generation
├── docs/                   # Comprehensive documentation
├── ci/                     # CI/CD configurations and scripts
└── bootstrap.sh            # Sets up Ansible virtual environment
```

### Ansible Role Categories

**Bastion roles** (`bastion-*`): Configure services on the bastion host
- `bastion-assisted-installer`: Deploys Assisted Installer service (core deployment engine)
- `bastion-registry`: Sets up container image registry with mirroring
- `bastion-dnsmasq`/`bastion-coredns`: DNS services for cluster nodes
- `bastion-haproxy`: Reverse proxy for cluster API/console access
- `bastion-http`: HTTP server for serving boot ISOs and configs
- `bastion-object-store`: RustFS S3-compatible object storage
- `bastion-proxy`: Squid proxy for disconnected environments

**Installation roles**: Handle cluster deployment
- `create-ai-cluster`: Creates cluster definition in Assisted Installer API
- `generate-discovery-iso`: Generates discovery ISO for bare metal boot
- `boot-iso`: Configures nodes to boot from discovery ISO via BMC virtual media
- `install-cluster`: Monitors and drives cluster installation to completion
- `sno-post-cluster-install`: Post-installation SNO-specific configuration

**Hypervisor roles** (`hv-*`): Manage VM infrastructure
- `hv-install`: Installs packages and configures hypervisor
- `hv-libvirt`: Configures libvirt, storage pools, networks
- `hv-vm-create`: Creates VMs for VMNO/hybrid deployments
- `hv-vm-delete`: Cleans up VMs
- `hv-dnsmasq`/`hv-coredns`: DNS services for VM networks

**Utility roles**: Supporting functionality
- `create-inventory`: Generates inventory from lab allocation data
- `configure-local-storage`: Sets up LSO (Local Storage Operator)
- `configure-odf`: Sets up ODF (OpenShift Data Foundation)
- `badfish`: Manages Dell BMC boot order via Badfish tool

### Key Playbook Patterns

**Naming Convention**: `<action>-<target>.yml`
- Deployment playbooks: `mno-deploy.yml`, `sno-deploy.yml`, `ibmcloud-mno-deploy.yml`
- Setup playbooks: `setup-bastion.yml`, `hv-setup.yml`
- Management playbooks: `hv-vm-create.yml`, `bastion-object-store-clean.yml`

**Playbook Structure**: Typically imports roles in dependency order
```yaml
---
- name: Playbook description
  hosts: bastion
  gather_facts: true
  roles:
    - role: prerequisite-role
    - role: main-role
    - role: post-configuration-role
```

## Variable Management

### Variable Precedence (Highest to Lowest)
1. Command-line `-e` extra vars
2. Role defaults (`ansible/roles/*/defaults/main.yml`)
3. `ansible/vars/all.yml` (user-edited for Red Hat labs)
4. `ansible/vars/ibmcloud.yml` (user-edited for IBMcloud)
5. `ansible/vars/lab.yml` (hardware definitions, DO NOT MODIFY)

### Critical Variable Files

**`ansible/vars/lab.yml`**: Hardware definitions and capabilities
- Maps hardware types to NIC names, disk paths, BMC types
- Defines VM capacity per hardware type (`hw_vm_counts`)
- **NEVER edit this file** - hardware onboarding uses the `hw-onboard` skill
- When adding new hardware, update this file via skill, not manually

**`ansible/vars/all.sample.yml`**: Template for Red Hat lab deployments
- Users copy to `all.yml` and customize
- Contains ~100+ variables controlling all aspects of deployment
- Key sections: lab selection, cluster type, OCP version, networking, storage

**`ansible/vars/ibmcloud.sample.yml`**: Template for IBMcloud deployments
- Simpler than `all.yml` (fewer options due to cloud environment)
- IBMcloud CLI provides machine inventory instead of QUADS

### Variable Naming Conventions
- `setup_*`: Boolean flags to enable/disable features (e.g., `setup_odf: true`)
- `bastion_*`: Bastion host configuration (e.g., `bastion_lab_interface`)
- `controlplane_*`: Control plane network settings
- `*_version`: Version strings for software components
- `enable_*`: Feature toggles (similar to `setup_*`)

## Ansible Development Patterns

### Role Structure
```
ansible/roles/example-role/
├── defaults/
│   └── main.yml          # Default variables (lowest precedence)
├── tasks/
│   └── main.yml          # Main task list
├── templates/
│   └── config.j2         # Jinja2 templates
├── files/
│   └── script.sh         # Static files
└── handlers/
    └── main.yml          # Handlers for service restarts, etc.
```

### Common Task Patterns

**Conditional Execution**:
```yaml
- name: Task description
  module_name:
    param: value
  when: condition_variable | bool
```

**Looping Over Lists**:
```yaml
- name: Configure multiple items
  module_name:
    param: "{{ item }}"
  loop: "{{ list_variable }}"
```

**Delegating to Bastion**:
```yaml
- name: Run on bastion from other hosts
  module_name:
    param: value
  delegate_to: "{{ bastion_machine }}"
  run_once: true
```

**BMC Operations** (Dell iDRAC):
```yaml
- name: Power on machine
  community.general.redfish_command:
    category: Systems
    command: PowerOn
    baseuri: "{{ bmc_address }}"
    username: "{{ bmc_user }}"
    password: "{{ bmc_password }}"
```

**API Interactions** (Assisted Installer):
```yaml
- name: Create cluster
  uri:
    url: "http://{{ assisted_installer_host }}:{{ assisted_installer_port }}/api/assisted-install/v2/clusters"
    method: POST
    body_format: json
    status_code: [201]
    body:
      name: "{{ cluster_name }}"
      # ... more parameters
  register: cluster_response
```

### Template Patterns

**Jinja2 Templates**: Use `.j2` extension
- Reference variables: `{{ variable_name }}`
- Conditionals: `{% if condition %} ... {% endif %}`
- Loops: `{% for item in list %} ... {% endfor %}`
- Filters: `{{ variable | default('default_value') }}`

**Common Filters Used**:
- `| default('value')`: Provide default if undefined
- `| bool`: Convert to boolean
- `| int`: Convert to integer
- `| regex_replace('pattern', 'replacement')`: Regex substitution
- `| to_json`: Convert to JSON string
- `| from_json`: Parse JSON string

## Development Workflows

### Adding a New Feature

1. **Identify the scope**: Which cluster types (MNO/SNO/VMNO)? Which environments (Scale Lab/Performance Lab/IBMcloud)?

2. **Create or modify role**:
   - Add new role under `ansible/roles/` if significant new functionality
   - Modify existing role if extending current capability
   - Add variables to role's `defaults/main.yml` with sensible defaults

3. **Update variable samples**:
   - Add new variables to `ansible/vars/all.sample.yml` with comments
   - Add to `ansible/vars/ibmcloud.sample.yml` if applicable
   - Document in appropriate `docs/*.md` file

4. **Update playbooks**:
   - Add role to relevant deployment playbooks
   - Consider conditional inclusion: `when: setup_feature | default(false) | bool`

5. **Test thoroughly**:
   - Test all affected cluster types
   - Verify feature can be disabled without breaking deployment
   - Check both fresh deployments and existing clusters

### Modifying Networking Configuration

**Critical**: Networking is environment-specific and error-prone
- Network interfaces vary by hardware (see `ansible/vars/lab.yml`)
- Variables: `bastion_lab_interface`, `bastion_controlplane_interface`
- Most network issues stem from incorrect interface names
- Always validate with `ip addr show` on target hardware

**Common Patterns**:
```yaml
- name: Configure network interface
  template:
    src: ifcfg-interface.j2
    dest: "/etc/sysconfig/network-scripts/ifcfg-{{ interface_name }}"
  notify: restart NetworkManager
```

### Working with BMC/iDRAC

**Dell Hardware** (Redfish API):
- Use `community.general.redfish_*` modules
- Common operations: power on/off, set boot device, virtual media
- Always check `redfish_facts` first to understand current state

**Supermicro Hardware** (IPMI):
- Requires SMCIPMITool binary (proprietary)
- Use `shell` module with `smcipmitool` commands
- More limited than Redfish, less reliable

**Best Practices**:
- Always set timeouts for BMC operations (they can hang)
- Implement retries for flaky BMC connections
- Log BMC responses for debugging
- Check BMC accessibility before attempting operations

### Storage Configuration

**LSO (Local Storage Operator)**:
- Role: `configure-local-storage`
- Two modes: LVM (logical volumes) or disk (raw block devices)
- Configuration: `lso_disks` (disk paths), `lso_disk_size` (LVM size)
- Creates storage classes: `localstorage-sc` (LVM) or `localstorage-disk-sc` (raw)

**ODF (OpenShift Data Foundation)**:
- Role: `configure-odf`
- Requires: 3+ worker nodes with additional disks
- Configuration: `odf_disks` (disk paths per node)
- Creates storage classes: `ocs-storagecluster-ceph-rbd` (RWO), `ocs-storagecluster-cephfs` (RWX)

**Default Storage Class Logic** (in `sno-post-cluster-install` role):
```
If set_default_storage_class is true (default):
  If ODF enabled: set ocs-storagecluster-cephfs as default
  Elif LSO with LVM: set localstorage-sc as default
  Elif LSO with disk: set localstorage-disk-sc as default
```

### Assisted Installer API Workflow

**Typical Flow**:
1. Create cluster definition (`create-ai-cluster` role)
2. Generate discovery ISO (`generate-discovery-iso` role)
3. Boot nodes from ISO via virtual media (`boot-iso` role)
4. Wait for nodes to appear in cluster (`install-cluster` role)
5. Start installation when ready
6. Monitor installation progress
7. Wait for completion

**API Endpoints** (all under `/api/assisted-install/v2/`):
- `/clusters`: CRUD for cluster definitions
- `/infra-envs`: Infrastructure environments (discovery ISO config)
- `/clusters/{id}/hosts`: Hosts discovered in cluster
- `/clusters/{id}/actions/install`: Trigger installation

**Common Response Patterns**:
- 201: Created
- 200: Success
- 404: Not found
- 409: Conflict (e.g., cluster name already exists)

### Virtual Machine Management

**VMNO Pattern**:
1. Set `cluster_type: vmno` in `all.yml`
2. Configure hypervisors: `ansible-playbook hv-setup.yml`
3. Create VMs: `ansible-playbook hv-vm-create.yml`
4. Deploy cluster to VMs: `ansible-playbook mno-deploy.yml`
5. Clean up: `ansible-playbook hv-vm-delete.yml`

**Hybrid MNO Pattern**:
- Set both `worker_node_count` (bare metal) and `hybrid_worker_count` (VMs)
- Inventory generation automatically allocates machines
- VMs distributed across hypervisor nodes

**VM Creation Details** (`hv-vm-create` role):
- Uses libvirt with qemu/KVM
- VMs defined via XML templates
- Storage: qcow2 images on hypervisor local disks
- Networking: libvirt network with static DHCP assignments
- VM count per hypervisor from `hw_vm_counts` in `lab.yml`

## Testing and Validation

### Pre-Deployment Validation

**Inventory Validation**:
```bash
# Verify inventory was generated correctly
cat ansible/inventory/$CLOUDNAME.local

# Check bastion is first machine
# Check control-plane has 3 nodes (MNO)
# Check worker count matches worker_node_count
```

**Variable Validation**:
```bash
# Check for undefined variables
ansible-playbook --syntax-check ansible/mno-deploy.yml

# Dry run to catch errors
ansible-playbook --check ansible/setup-bastion.yml
```

**Network Validation** (on bastion):
```bash
# Verify interface names match configuration
ip addr show

# Test BMC connectivity
ping <bmc_address>

# Test DNS resolution
nslookup api.cluster.example.com
```

### Post-Deployment Validation

**Cluster Health**:
```bash
# SSH to bastion, then:
export KUBECONFIG=/root/mno/kubeconfig  # or /root/sno/<cluster-name>/kubeconfig

# Check nodes
oc get nodes

# Check cluster operators
oc get co

# Check for degraded operators
oc get co | grep -v "True.*False.*False"

# Check pods
oc get pods -A | grep -v Running | grep -v Completed
```

**Storage Validation**:
```bash
# Check storage classes
oc get sc

# Verify default storage class
oc get sc | grep default

# For LSO, check local volumes
oc get localvolume -n openshift-local-storage

# For ODF, check storage cluster
oc get storagecluster -n openshift-storage
```

**VM Validation** (for VMNO/hybrid):
```bash
# On hypervisor node:
virsh list --all

# Check VM is running
virsh dominfo <vm-name>

# Check VM network
virsh domifaddr <vm-name>
```

### Common Validation Failures

**BMC Issues**:
- Symptom: "Failed to connect to BMC"
- Check: BMC IP reachable, credentials correct
- Debug: `ipmitool -I lanplus -H <bmc> -U <user> -P <pass> power status`

**Network Issues**:
- Symptom: Nodes don't appear in Assisted Installer
- Check: DHCP working, DNS configured, discovery ISO booted
- Debug: Check bastion dnsmasq logs, verify ISO mounted in iDRAC

**Storage Issues**:
- Symptom: PVCs stuck in Pending
- Check: Storage class exists, default SC set, LSO/ODF pods running
- Debug: `oc describe pvc <name>`, check LSO/ODF operator logs

**Assisted Installer Issues**:
- Symptom: Cluster stuck in "Insufficient" state
- Check: All nodes discovered, validation errors in UI
- Debug: Check cluster validation status via API

## Common Pitfalls and Anti-Patterns

### DO NOT

1. **Modify `ansible/vars/lab.yml` manually**
   - Use `hw-onboard` skill for hardware additions
   - This file is the single source of truth for hardware capabilities

2. **Hardcode hardware-specific values in roles**
   - Always reference `lab.yml` variables
   - Example: Use `{{ hardware_type.disk }}`, not `/dev/sda`

3. **Assume network interface names**
   - Interface names vary: `eno`, `ens`, `enp`, `em`, etc.
   - Always use variables from `lab.yml` or user configuration

4. **Skip inventory generation**
   - Always run `create-inventory.yml` playbook
   - Manual inventory creation only for "Bring Your Own Lab"

5. **Commit sensitive data**
   - `pull-secret.txt`, `ansible/vars/all.yml`, `ansible/vars/ibmcloud.yml` are gitignored
   - Never commit credentials, API tokens, or pull secrets

6. **Use `yum` instead of `dnf`**
   - RHEL 9+ uses `dnf` (yum is compatibility symlink)
   - Use `ansible.builtin.dnf` module, not `yum`

7. **Forget to handle idempotency**
   - Ansible should be safe to re-run
   - Use `creates`, `unless`, or check state before changing

8. **Mix cluster types in same allocation**
   - One allocation = one cluster type (MNO or SNO or VMNO)
   - Don't try to deploy MNO and SNO simultaneously

### DO

1. **Check documentation first**
   - `docs/troubleshooting.md` covers 90% of common issues
   - `docs/tips-and-vars.md` for advanced configurations

2. **Use appropriate modules**
   - `uri` for HTTP APIs (Assisted Installer)
   - `redfish_*` for Dell BMCs
   - `dnf` for package management
   - `systemd` for service management

3. **Implement retries for flaky operations**
   - BMC operations can timeout
   - API calls can have transient failures
   ```yaml
   retries: 3
   delay: 10
   register: result
   until: result is succeeded
   ```

4. **Log important information**
   - Use `debug` module to log key variables
   - Register API responses for debugging
   - Use `failed_when` to customize failure conditions

5. **Make features optional**
   - Use `setup_*` or `enable_*` variables
   - Default to `false` for new features
   - Allow users to opt-in

6. **Consider all cluster types**
   - New features should work with MNO, SNO, and VMNO where applicable
   - Use `when: cluster_type == 'mno'` for type-specific tasks

7. **Update documentation**
   - Add new variables to sample files with clear comments
   - Document in relevant `docs/*.md` files
   - Update CLAUDE.md if user-facing

## Code Style and Conventions

### YAML Style

**Indentation**: 2 spaces (no tabs)

**List vs Dictionary**:
```yaml
# List (dash + space)
list_var:
  - item1
  - item2

# Dictionary (key: value)
dict_var:
  key1: value1
  key2: value2
```

**Multiline Strings**:
```yaml
# Literal block (preserves newlines)
script: |
  #!/bin/bash
  echo "Line 1"
  echo "Line 2"

# Folded block (folds newlines to spaces)
description: >
  This is a long description
  that will be folded into
  a single line.
```

### Ansible Task Style

**Preferred Format**:
```yaml
- name: Clear, descriptive action in present tense
  module.name:
    parameter1: value1
    parameter2: value2
  when: condition
  register: variable_name
  tags:
    - tag1
```

**Task Names**:
- Start with capital letter
- Use present tense ("Install package", not "Installing package")
- Be specific ("Install podman" vs "Install packages")
- Match what the task actually does

**Module Parameters**:
- One parameter per line for readability
- Alphabetize if many parameters
- Use full module name (`ansible.builtin.copy`, not just `copy`) for clarity

### Variable Naming

**Patterns**:
- Use snake_case: `cluster_name`, not `clusterName`
- Be descriptive: `assisted_installer_port`, not `ai_port`
- Use prefixes for grouping: `bastion_*`, `ocp_*`, `controlplane_*`
- Booleans should imply true/false: `setup_registry`, `enable_fips`

**Example**:
```yaml
# Good
setup_local_storage: true
bastion_controlplane_interface: ens1f0
ocp_version: "4.20"

# Avoid
lso: yes  # not descriptive
iface: ens1f0  # unclear which interface
version: "4.20"  # too generic
```

### Comments

**Role README**: Each role should document:
- Purpose and scope
- Required variables
- Optional variables with defaults
- Example usage

**Inline Comments**: Use sparingly
- Explain *why*, not *what* (code shows what)
- Clarify non-obvious logic
- Document workarounds with references (e.g., "Workaround for OCPBUGS-12345")

**Variable Comments** (in defaults/sample files):
```yaml
# Brief description of purpose
# Possible values: value1, value2
# Default: value1 if not specified
variable_name: default_value
```

## File Organization

### When to Create a New Role

**Create a new role when**:
- Functionality is self-contained and reusable
- Multiple playbooks need the same logic
- Role exceeds ~200 lines and can be split logically

**Extend existing role when**:
- Feature is directly related to role's purpose
- Adding a few tasks to existing flow
- Complexity doesn't warrant separation

### When to Create a New Playbook

**Create a new playbook when**:
- New user-facing workflow emerges
- Existing playbook becomes too complex (>10 roles)
- Different host targets required

**Add to existing playbook when**:
- Extension of current workflow
- Same host targets and role dependencies

### Template Organization

**Location**: `ansible/roles/<role>/templates/`

**Naming**: `<purpose>.<type>.j2`
- Examples: `dnsmasq.conf.j2`, `cluster-definition.json.j2`

**Complex Templates**: Consider breaking into includes
```jinja2
{# Main template #}
{% include 'header.j2' %}
{% include 'body.j2' %}
{% include 'footer.j2' %}
```

## Debugging Tips

### Ansible Verbosity
```bash
# Standard output
ansible-playbook playbook.yml

# Verbose (-v, -vv, -vvv, -vvvv)
ansible-playbook -vvv playbook.yml

# Show diff for template changes
ansible-playbook --diff playbook.yml

# Syntax check only
ansible-playbook --syntax-check playbook.yml

# Dry run (check mode)
ansible-playbook --check playbook.yml
```

### Debugging Failed Tasks

**Use `debug` module**:
```yaml
- name: Show variable value
  debug:
    var: variable_name
    verbosity: 1  # Only show with -v or higher
```

**Check registered variables**:
```yaml
- name: Run command
  shell: some command
  register: result

- name: Show result
  debug:
    var: result
```

**Inspect JSON responses**:
```yaml
- name: Show parsed response
  debug:
    msg: "Cluster ID: {{ cluster_response.json.id }}"
```

### Common Debug Locations

**Bastion logs**:
- Assisted Installer: `journalctl -u assisted-installer`
- dnsmasq: `journalctl -u dnsmasq`
- podman containers: `podman logs <container>`

**Cluster logs** (via oc):
- Operator logs: `oc logs -n <namespace> deployment/<operator-name>`
- Node logs: `oc debug node/<node-name>` then `chroot /host`

**Ansible facts**:
```yaml
- name: Gather and display all facts
  debug:
    var: ansible_facts
```

## Integration with CI/CD

### CI Configuration

**Location**: `ci/` directory
- Prow job definitions
- Test scripts
- Helper utilities

**Skill Integration**:
- `jetlag-prow-analyze`: Analyze failed Prow logs
- `jetlag-prow-trigger`: Trigger Prow tests on PR
- `jetlag-test-map`: Map file changes to required tests

### PR Review Workflow

**Skills**:
- `jetlag-review`: Fetch and review a PR
- `jetlag-issue-fix`: Full issue-to-fix-to-test workflow

**Manual Review Checklist**:
1. Variable samples updated?
2. Documentation updated?
3. Backward compatible?
4. Works with all cluster types?
5. Works in all environments (Scale Lab/Performance Lab/IBMcloud)?
6. Idempotent (safe to re-run)?

## Related Documentation

### Essential Reading
- [CLAUDE.md](CLAUDE.md) - User-facing deployment guide and essential commands
- [docs/troubleshooting.md](docs/troubleshooting.md) - Comprehensive troubleshooting
- [docs/tips-and-vars.md](docs/tips-and-vars.md) - Advanced configuration tips

### Role-Specific Documentation
- [docs/bastion-setup.md](docs/bastion-setup.md) - Bastion configuration deep dive
- [docs/bastion-registry.md](docs/bastion-registry.md) - Registry mirroring details
- [docs/bastion-haproxy.md](docs/bastion-haproxy.md) - HAProxy cluster access
- [docs/bastion-object-store.md](docs/bastion-object-store.md) - RustFS S3 storage
- [docs/local-storage.md](docs/local-storage.md) - LSO configuration
- [docs/odf.md](docs/odf.md) - ODF setup and usage

### Deployment Guides
- [docs/deploy-mno.md](docs/deploy-mno.md) - MNO deployment walkthrough
- [docs/deploy-sno.md](docs/deploy-sno.md) - SNO deployment walkthrough
- [docs/deploy-vmno.md](docs/deploy-vmno.md) - VMNO deployment walkthrough
- [docs/deploy-mno-ibmcloud.md](docs/deploy-mno-ibmcloud.md) - IBMcloud MNO
- [docs/deploy-mno-byol.md](docs/deploy-mno-byol.md) - Bring Your Own Lab

### Advanced Topics
- [docs/hypervisors.md](docs/hypervisors.md) - VM/hypervisor management
- [docs/hv-metrics.md](docs/hv-metrics.md) - Hypervisor monitoring
- [docs/scale-out-mno.md](docs/scale-out-mno.md) - Adding workers to MNO
- [docs/custom-catalogsources.md](docs/custom-catalogsources.md) - Custom operators

## Quick Reference

### Variable Lookup Priority
```
1. Command line (-e)
2. Role defaults
3. ansible/vars/all.yml or ansible/vars/ibmcloud.yml
4. ansible/vars/lab.yml (hardware definitions)
```

### Common File Paths
```
User configs:
  ansible/vars/all.yml                    # Red Hat labs config
  ansible/vars/ibmcloud.yml               # IBMcloud config
  pull-secret.txt                         # OCP pull secret

Generated files:
  ansible/inventory/<cloud>.local         # Inventory file

Kubeconfigs (on bastion):
  /root/mno/kubeconfig                    # MNO cluster
  /root/vmno/kubeconfig                   # VMNO cluster  
  /root/sno/<cluster-name>/kubeconfig     # SNO clusters

Bastion services:
  /opt/assisted-installer/                # Assisted Installer
  /opt/registry/                          # Container registry
  /opt/http_store/data/                   # HTTP server files
```

### Quick Commands
```bash
# Setup environment
source bootstrap.sh

# Generate inventory
ansible-playbook ansible/create-inventory.yml

# Deploy MNO cluster (Red Hat labs)
ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml

# Deploy SNO clusters
ansible-playbook -i ansible/inventory/cloud99.local ansible/sno-deploy.yml

# Deploy VMNO cluster
ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-setup.yml
ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-create.yml
ansible-playbook -i ansible/inventory/cloud99.local ansible/mno-deploy.yml

# Clean up VMs
ansible-playbook -i ansible/inventory/cloud99.local ansible/hv-vm-delete.yml

# Validate cluster
oc get nodes
oc get co
oc get sc
```

### Module Quick Reference
```yaml
# HTTP API call
- uri:
    url: http://example.com/api
    method: POST
    body_format: json
    body: { key: value }
    status_code: [200, 201]
  register: response

# Dell BMC (Redfish)
- community.general.redfish_command:
    category: Systems
    command: PowerOn
    baseuri: "{{ bmc_address }}"
    username: "{{ bmc_user }}"
    password: "{{ bmc_password }}"

# Service management
- ansible.builtin.systemd:
    name: service-name
    state: started
    enabled: true

# Package management
- ansible.builtin.dnf:
    name: package-name
    state: present

# Copy template
- ansible.builtin.template:
    src: config.j2
    dest: /etc/config.conf
  notify: restart service

# Run command
- ansible.builtin.shell: |
    command with
    multiple lines
  args:
    creates: /path/to/file  # Skip if exists
```

---

**Note**: This document focuses on development patterns. For operational procedures and troubleshooting, see [CLAUDE.md](CLAUDE.md) and [docs/troubleshooting.md](docs/troubleshooting.md).
