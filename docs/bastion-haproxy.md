# Accessing Clusters via Bastion HAProxy

Jetlag can configure HAProxy on the bastion machine to proxy cluster access from your laptop to **MNO clusters** on private or internal networks. The HAProxy instance proxies traffic over ports 6443 (API), 443 (HTTPS routes), and 80 (HTTP routes), allowing you to access the cluster API, web console, and other cluster routes from your laptop.

> [!NOTE]
> HAProxy is only for MNO clusters that use VIPs. HAProxy is not implemented for SNO deployments.

## Use Cases

### 1. Connected IPv4 Clusters on Private Networks

For **connected IPv4 clusters** deployed on private lab networks (e.g., `192.168.x.x`, `198.18.x.x`) where you want GUI/API access from your laptop, you can enable HAProxy to proxy traffic through the bastion.

**Configuration:**

1. Edit `ansible/vars/all.yml`:
   ```yaml
   setup_bastion_haproxy: true
   ```

2. Run or re-run the bastion setup playbook:
   ```bash
   ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
   ```

3. The playbook will:
   - Install and configure HAProxy on the bastion
   - Generate a hosts file at `/root/mno/hosts` (or `/root/vmno/hosts` for VMNO clusters)

### 2. Disconnected IPv6 Clusters (Automatic)

For **disconnected/air-gapped IPv6 clusters** using the bastion registry (`use_bastion_registry: true`), HAProxy is **automatically enabled** without needing to set `setup_bastion_haproxy`. The bastion registry setup triggers HAProxy configuration to provide cluster access.

**Configuration:**
```yaml
# IPv6 disconnected cluster
controlplane_network: ['fd00:198:18::/64']
use_bastion_registry: true
# HAProxy automatically enabled - no need to set setup_bastion_haproxy
```

### 3. IPv6 Clusters with Squid Proxy (Automatic)

For **IPv6 clusters** using Squid forward proxy (`setup_bastion_proxy: true`), HAProxy is **automatically enabled** to provide cluster access alongside the forward proxy configuration.

**Configuration:**
```yaml
# IPv6 cluster with forward proxy
controlplane_network: ['fd00:198:18::/64']
setup_bastion_proxy: true
# HAProxy automatically enabled - no need to set setup_bastion_haproxy
```

## Laptop Configuration

After HAProxy is configured on the bastion, you need to update your laptop's `/etc/hosts` file to route cluster DNS names through the bastion.

### Step 1: Copy the Hosts File

The `setup-bastion.yml` playbook generates an example hosts file at `{{ bastion_cluster_config_dir }}/hosts` (typically `/root/mno/hosts` for MNO.

```bash
# Copy hosts file from bastion to your laptop
scp bastion:/root/mno/hosts ~/bastion-cluster-hosts

# Review the contents
cat ~/bastion-cluster-hosts
```

### Step 2: Update Your Laptop's /etc/hosts

Append the contents to your `/etc/hosts` file:

```bash
sudo tee -a /etc/hosts < ~/bastion-cluster-hosts
```

Or manually edit `/etc/hosts` and add entries like:

```
$BASTION_IP api.mno.example.com
$BASTION_IP oauth-openshift.apps.mno.example.com
$BASTION_IP console-openshift-console.apps.mno.example.com
$BASTION_IP downloads-openshift-console.apps.mno.example.com
$BASTION_IP alertmanager-main-openshift-monitoring.apps.mno.example.com
$BASTION_IP prometheus-k8s-openshift-monitoring.apps.mno.example.com
$BASTION_IP thanos-querier-openshift-monitoring.apps.mno.example.com
$BASTION_IP assisted-service-open-cluster-management.apps.mno.example.com
```

**Where `$BASTION_IP`** is the IP address you use to access the bastion from your laptop (typically the bastion's lab network IP).

### Step 3: Access the Cluster

You can now access cluster services from your laptop:

- **Web Console:** `https://console-openshift-console.apps.mno.example.com`
- **API (oc/kubectl):** `https://api.mno.example.com:6443`

If you create additional routes, append them to your `/etc/hosts` file with the same `$BASTION_IP` prefix.
