---
description: Onboard new hardware into Jetlag - discover NIC/disk config and update lab.yml
argument-hint: "<hw_model> <lab> [quads_cloud_or_hostname]"
---

You are the orchestrator for onboarding new server hardware into Jetlag. This skill walks through hardware discovery, configuration, and validation.

**IMPORTANT**: Hardware details (NIC names, disk paths) MUST be discovered from the actual hardware, never guessed.

## Related Files

- `ansible/vars/lab.yml` — Central hardware configuration (vendor, NICs, disks, VM counts)
- `ansible/roles/create-inventory/tasks/main.yml` — Disk2 detection for hypervisor nodes
- `docs/tips-and-vars.md` — Hardware documentation tables

## Input

- `$ARGUMENTS` — Space-separated: `<hw_model>` `<lab>` `[quads_cloud_or_hostname]`
  - `hw_model`: Server model identifier (e.g., `r6625`, `r770`, `dl380`)
  - `lab`: Lab environment (`scalelab` or `performancelab`)
  - `quads_cloud_or_hostname`: Either a QUADS cloud name (e.g., `cloud04`) or a direct hostname (e.g., `f11-h16-000-r6625.rdu2.scalelab.redhat.com`)

## Phase 1: PRE-FLIGHT CHECKS

1. Parse `$ARGUMENTS` into `HW_MODEL`, `LAB`, and `TARGET`.

2. Check if `HW_MODEL` already exists in `ansible/vars/lab.yml`:
   ```bash
   grep -c "^  ${HW_MODEL}:" ansible/vars/lab.yml
   ```
   If fully configured (vendor + NIC + disk), inform the user and stop.

3. Determine the vendor from the model name convention:
   - Dell: r-series (r630, r660, r6625, r760), fc-series (fc640), xe-series (xe8640), mx-series (mx750c)
   - Supermicro: numeric (1029u, 6049p, 5039ms)
   - HP: dl-series (dl360)
   - If unclear, ask the user.

4. Determine how to access hardware:
   - If `TARGET` looks like a hostname (contains `.`): use it directly for SSH.
   - If `TARGET` looks like a cloud name (e.g., `cloud04`): resolve hosts via QUADS API.
   - If `TARGET` is empty: ask the user for a hostname or QUADS cloud.

## Phase 2: DISCOVER HARDWARE DETAILS

### 2a. Resolve Host Access

If using QUADS cloud name:
```bash
# Get QUADS server for the lab
QUADS_HOST=$(yq -r ".labs.${LAB}.quads" ansible/vars/lab.yml)

# List hosts in the cloud
curl -sk "https://${QUADS_HOST}/api/v3/hosts?cloud_id=$(
  curl -sk "https://${QUADS_HOST}/api/v3/clouds?name=${TARGET}" | jq -r '.[0].id'
)" | jq -r '.[].name'
```
Use the first host for discovery.

### 2b. Discover NIC Names and MAC Addresses

SSH into the host and collect:

```bash
# Get all NIC names with MACs
for iface in $(ls /sys/class/net/ | grep -v lo); do
  mac=$(cat /sys/class/net/$iface/address)
  state=$(cat /sys/class/net/$iface/operstate)
  speed=$(cat /sys/class/net/$iface/speed 2>/dev/null || echo "?")
  echo "$iface: mac=$mac state=$state speed=${speed}Mbps"
done
```

```bash
# Identify which NIC has the lab IP (this is nic[0] / lab interface)
ip -4 addr show | grep "inet " | grep -v 127.0.0
```

### 2c. Cross-Reference with QUADS Interface Data

```bash
# Get QUADS interface names and MACs (sorted by BIOS name)
curl -sk "https://${QUADS_HOST}/api/v3/hosts/${HOSTNAME}" | \
  jq '.interfaces | sort_by(.name) | .[] | "\(.name): mac=\(.mac_address) speed=\(.speed)G port=\(.switch_port)"'
```

### 2d. Build the NIC-to-Network Mapping

**CRITICAL**: The `hw_nic_name` list MUST be ordered to match the QUADS MAC index order:

1. `nic[0]` = lab/public interface (the NIC with the DHCP lab IP, may NOT be in QUADS)
2. `nic[1]` = Network 1 = Linux NIC whose MAC matches QUADS `mac[0]` (first BIOS-sorted interface)
3. `nic[2]` = Network 2 = Linux NIC whose MAC matches QUADS `mac[1]`
4. Continue for all QUADS interfaces...
5. Last entry = usually the second port of the lab NIC pair

**Why this ordering matters**: The `controlplane_network_interface_idx` (default 0) selects `mac[0]` from QUADS for the controlplane nodes. The bastion controlplane interface is set from `hw_nic_name[idx+1]`. If these point to NICs on different physical networks, nodes can't reach the bastion and discovery fails silently.

**Mapping procedure**:
```
For each QUADS interface (sorted by BIOS name em1, em2, ...):
  1. Note its MAC address
  2. Find which Linux NIC has that MAC: grep <mac> /sys/class/net/*/address
  3. That Linux NIC name goes at position [quads_index + 1] in hw_nic_name
```

### 2e. Discover Install Disk Path

```bash
# Find the boot disk
BOOT_DISK=$(lsblk -no PKNAME $(findmnt -n -o SOURCE /boot) | head -1)
echo "Boot disk: $BOOT_DISK"

# Get its by-path link
find /dev/disk/by-path -lname "*$BOOT_DISK" | grep -v part
```

### 2f. Discover Additional Disks (for VM counts)

```bash
# List all disks and sizes
lsblk -d -o NAME,SIZE,TYPE | grep disk

# Check for nvme drives
ls /dev/nvme* 2>/dev/null

# List all by-path links
ls -la /dev/disk/by-path/ | grep -v part
```

**Present all discovered data to the user for confirmation before proceeding.**

## Phase 3: UPDATE CONFIGURATION

### 3a. Update `ansible/vars/lab.yml`

Add entries to these sections (in alphabetical order within each section):

1. **`hw_vendor`**: Add `HW_MODEL: <Vendor>`
2. **`hw_install_disk`**: Add under the correct lab section
3. **`hw_nic_name`**: Add under the correct lab section with the mapped NIC list
4. **`hw_vm_counts`**: Add under the correct lab section. Estimate based on similar hardware:
   - `default`: VM count using only the boot disk (conservative)
   - Add extra disk entries (e.g., `nvme0n1`, `sdb`) if the hardware has additional disks

### 3b. Update `ansible/roles/create-inventory/tasks/main.yml`

If the hardware has a second disk (nvme0n1, sdb, etc.), add it to the appropriate disk2 detection task:
- nvme0n1 → add to the `r650, r660, r750, ...` list (line ~481)
- sdb → add to the `r630` list (line ~449) or `5039ms, dl360` list (line ~499)
- If it needs dynamic detection like r640 → add a new detection block

### 3c. Update Documentation

Add entries to `docs/tips-and-vars.md`:
- Network interface table for the lab
- Install disk table for the lab

## Phase 4: VALIDATE CONFIGURATION

Run the create-inventory playbook to verify the configuration generates a valid inventory:

```bash
source .ansible/bin/activate
ansible-playbook ansible/create-inventory.yml
```

Check the generated inventory file for:
- Correct `bastion_lab_interface`
- Correct `bastion_controlplane_interface`
- Correct `controlplane_lab_interface`
- Correct `install_disk` paths on all nodes
- Correct `vendor` on all nodes

## Phase 5: TEST DEPLOYMENT (Optional)

If the user wants to test end-to-end:

1. Run bastion setup:
   ```bash
   ansible-playbook -i ansible/inventory/<cloud>.local ansible/setup-bastion.yml
   ```

2. Run cluster deployment:
   ```bash
   ansible-playbook -i ansible/inventory/<cloud>.local ansible/mno-deploy.yml
   ```

3. Verify cluster health:
   ```bash
   ssh root@<bastion> "export KUBECONFIG=/root/mno/kubeconfig && oc get nodes && oc get clusterversion"
   ```

## Common Pitfalls

1. **NIC ordering mismatch**: The most common failure. QUADS BIOS names (em1, em2...) don't always match Linux naming. em1 might be `ens2f0` not `ens1f0`. Always cross-reference MACs.

2. **Lab NIC not in QUADS**: The lab/public NIC (nic[0]) is often NOT listed in QUADS interfaces. It gets its IP via DHCP from foreman. Don't confuse it with the QUADS interface list.

3. **QUADS validation timing**: If using self-schedule with `wipe=true`, wait for QUADS validation to complete before running bastion setup. QUADS will reinstall the OS and reboot machines during provisioning.

4. **Heterogeneous disk paths**: Some hardware models have different disk paths per rack or unit. Check multiple hosts if available. Use rack-specific overrides in `hw_install_disk` (e.g., `y37-r740xd`) when needed.

5. **AMD vs Intel NIC naming**: AMD-based servers (r6625, r7625, r7525) may use different NIC naming than their Intel counterparts (r660, r760, r750) even if the form factor is similar.
