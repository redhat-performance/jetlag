# Accessing Clusters via Bastion HAProxy

Jetlag can configure HAProxy on the bastion machine to proxy cluster access from your laptop to **MNO and VMNO clusters** on private or internal networks. The HAProxy instance proxies traffic over ports 6443 (API), 443 (HTTPS routes), and 80 (HTTP routes), allowing you to access the cluster API, web console, Grafana, and other cluster routes from your laptop.

**Note:** HAProxy is only for MNO/VMNO clusters that use VIPs. SNO clusters do not use VIPs and are accessed directly via each node's IP address - HAProxy is not applicable to SNO deployments.

## Use Cases

### 1. Connected IPv4 Clusters on Private Networks

For **connected IPv4 clusters** deployed on private lab networks (e.g., `192.168.x.x`, `198.18.x.x`) where you want GUI/API access from your laptop without VPN, you can manually enable HAProxy.

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

The `setup-bastion.yml` playbook generates an example hosts file at `{{ bastion_cluster_config_dir }}/hosts` (typically `/root/mno/hosts` for MNO or `/root/vmno/hosts` for VMNO).

```bash
# Copy hosts file from bastion to your laptop
scp bastion:/root/mno/hosts ~/bastion-cluster-hosts

# Review the contents
cat ~/bastion-cluster-hosts
```

### Step 2: Update Your Laptop's /etc/hosts

Append the contents to your `/etc/hosts` file:

```bash
sudo cat ~/bastion-cluster-hosts >> /etc/hosts
```

Or manually edit `/etc/hosts` and add entries like:

```
$BASTION_IP api.mno.example.com
$BASTION_IP oauth-openshift.apps.mno.example.com
$BASTION_IP console-openshift-console.apps.mno.example.com
$BASTION_IP downloads-openshift-console.apps.mno.example.com
$BASTION_IP alertmanager-main-openshift-monitoring.apps.mno.example.com
$BASTION_IP grafana-openshift-monitoring.apps.mno.example.com
$BASTION_IP prometheus-k8s-openshift-monitoring.apps.mno.example.com
$BASTION_IP thanos-querier-openshift-monitoring.apps.mno.example.com
$BASTION_IP assisted-service-open-cluster-management.apps.mno.example.com
$BASTION_IP multicloud-console.apps.mno.example.com
$BASTION_IP grafana-open-cluster-management-observability.apps.mno.example.com
```

**Where `$BASTION_IP`** is the IP address you use to access the bastion from your laptop (typically the bastion's lab network IP).

### Step 3: Access the Cluster

You can now access cluster services from your laptop:

- **Web Console:** `https://console-openshift-console.apps.mno.example.com`
- **Grafana:** `https://grafana-openshift-monitoring.apps.mno.example.com`
- **API (oc/kubectl):** `https://api.mno.example.com:6443`
- **ACM Console:** `https://multicloud-console.apps.mno.example.com`

If you create additional routes, append them to your `/etc/hosts` file with the same `$BASTION_IP` prefix.

## How It Works

### Ports Proxied

HAProxy on the bastion listens on the following ports and forwards traffic to the cluster:

| Port  | Protocol | Backend Target | Purpose |
|-------|----------|----------------|---------|
| 6443  | TCP      | API VIP (`.3` of controlplane network) | Kubernetes API access (`oc`, `kubectl`) |
| 22623 | TCP      | Control plane nodes | Machine Config Server |
| 443   | TCP      | Ingress VIP (`.4` of controlplane network) | HTTPS ingress routes (console, Grafana, etc.) |
| 80    | TCP      | Ingress VIP (`.4` of controlplane network) | HTTP ingress routes |
| 50000 | HTTP     | HAProxy stats dashboard | HAProxy statistics (username: `admin`, password: `password`) |

### Dual-Stack Support

HAProxy frontends bind to `:::port v4v6`, enabling dual-stack IPv4/IPv6 access. Backend server addresses are formatted based on IP version detection:

- **IPv4 addresses:** `192.168.10.3:6443` (no brackets)
- **IPv6 addresses:** `[fd00:198:18::3]:6443` (with brackets)

This automatic detection ensures HAProxy works correctly with both IPv4 and IPv6 clusters.

## Limitations

- **MNO/VMNO clusters only:** HAProxy only works with MNO and VMNO clusters that use API and Ingress VIPs. **SNO clusters are not supported** because they do not use VIPs - each SNO node is accessed directly via its own IP address. The playbook will fail validation if `setup_bastion_haproxy: true` is used with `cluster_type: sno`.
- **Cannot be used with `public_vlan: true`:** Public VLAN clusters have routable IP addresses and do not need HAProxy. The playbook will fail validation if both are enabled.
- **Requires SSH access to bastion:** You must be able to SSH to the bastion to copy the hosts file and access proxied services.
- **Local `/etc/hosts` modification required:** DNS resolution happens on your laptop, requiring manual `/etc/hosts` updates.

## Troubleshooting

### HAProxy Service Status

Check if HAProxy is running on the bastion:

```bash
ssh bastion
sudo systemctl status haproxy
```

### View HAProxy Configuration

```bash
ssh bastion
sudo cat /etc/haproxy/haproxy.cfg
```

Verify backend server addresses:
- **IPv4 clusters:** Should see addresses like `server api 192.168.10.3:6443`
- **IPv6 clusters:** Should see addresses like `server api [fd00:198:18::3]:6443`

### HAProxy Statistics Dashboard

Access HAProxy stats at: `http://$BASTION_IP:50000/haproxy?stats`

- **Username:** `admin`
- **Password:** `password`

This shows real-time connection statistics and backend health.

### Test Connectivity

From your laptop:

```bash
# Test API access
curl -k https://api.mno.example.com:6443/version

# Test console route
curl -k https://console-openshift-console.apps.mno.example.com
```

### Common Issues

**Issue:** "Connection refused" when accessing cluster services  
**Solution:** Verify HAProxy is running on bastion and your `/etc/hosts` entries are correct

**Issue:** HAProxy config has wrong address format  
**Solution:** Check that `controlplane_network` in `all.yml` matches your IP version (IPv4 vs IPv6)

**Issue:** Validation error about `public_vlan`  
**Solution:** Set `public_vlan: false` if using HAProxy, or remove `setup_bastion_haproxy: true` if using public VLAN
