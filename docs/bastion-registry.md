# Bastion Mirror Registry

The bastion mirror registry is a container image registry deployed on the bastion host using Podman. It is used in disconnected and IPv6 environments to serve OpenShift release images, operator catalogs, and custom container images to cluster nodes.

_**Table of Contents**_
<!-- TOC -->
- [Bastion Mirror Registry](#bastion-mirror-registry)
  - [Enabling the registry](#enabling-the-registry)
  - [Add/delete contents to the bastion registry](#adddelete-contents-to-the-bastion-registry)
  - [Bandwidth limiting](#bandwidth-limiting)
<!-- /TOC -->

## Enabling the registry

Set the following variables in `ansible/vars/all.yml` to enable the bastion registry:

```yaml
# Set to enable and sync container images into a container image registry on the bastion
setup_bastion_registry: true

# Use in conjunction with ipv6 based clusters
use_bastion_registry: true
```

The registry is deployed during `setup-bastion.yml` as a Podman pod named `registry` with a container named `bastion-registry`, listening on port 5000. It stores data under `/opt/registry/` on the bastion host.

## Add/delete contents to the bastion registry

There might be use-cases when you want to add and delete images to/from the bastion registry. For example, for the single stack IPv6 disconnected deployment, the deployment cannot reach quay.io to get the image for your containers.  In this situation, you may use the ICSP (ImageContentSecurityPolicy) mechanism in conjunction with image mirroring. When the deployment requests an image on quay.io, cri-o will intercept the request, redirect and map it to an image on the bastion/mirror registry.
For example, this policy will map images on quay.io/XXX/client-server to the mirror registry on perf176b, the bastion of this IPv6 disconnected cluster.
```yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: crucible-repo
spec:
  repositoryDigestMirrors:
  - mirrors:
    - perf176b.xxx.com:5000/XXX/client-server
    source: quay.io/XXX/client-server
```

For on-demand mirroring, the next command run on the bastion will mirror the image from quay.io to perf176b's disconnected registry.

```console
(.ansible) [root@<bastion> jetlag]# oc image mirror -a /opt/registry/pull-secret-bastion.txt perf176b.xxx.com:5000/XXX/client-server:<tag> --keep-manifest-list --continue-on-error=true
```
Once the image has successfully mirrored onto the disconnected registry, your deployment will be able to create the container.

For image deletion, use the Docker V2 REST API to delete the object. Note that the deletion operation argument has to be an image's digest not image's tag. So if you mirrored your image by tag in the previous step, on deletion you have to get its digest first. The following script resolves the digest and deletes an image by tag.

```bash
#!/bin/bash
# Usage: ./delete-image.sh <registry> <image-name> <tag>
# Example: ./delete-image.sh '[fc00:198:18:10::1]:5000' redhat/redhat-operator-index v4.17
#          ./delete-image.sh 'bastion.example.com:5000' ocp4/openshift4 4.17.17-x86_64

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <registry> <image-name> <tag>"
  echo "  registry    - Registry host:port (e.g. '[fc00:198:18:10::1]:5000')"
  echo "  image-name  - Image namespace/name (e.g. 'redhat/redhat-operator-index')"
  echo "  tag          - Image tag to delete (e.g. 'v4.17')"
  exit 1
fi

registry="$1"
name="$2"
tag="$3"
auth='-u registry:registry'

digest=$(curl $auth -sI -k \
  -H "Accept: application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.docker.distribution.manifest.list.v2+json" \
  "https://${registry}/v2/${name}/manifests/${tag}" \
  | tr -d '\r' | sed -En 's/^Docker-Content-Digest: (.*)/\1/pi')

if [[ -z "$digest" ]]; then
  echo "Error: Could not resolve digest for ${name}:${tag}"
  exit 1
fi

echo "Deleting ${name}:${tag} (digest: ${digest})"
curl $auth -X DELETE -sI -k "https://${registry}/v2/${name}/manifests/${digest}"
```

**Automating Image Mirroring**

Instead of manually running `oc image mirror` commands, you can automate mirroring generic container images into your bastion registry during the `sync-operator-index` playbook execution.

Simply add the `additional_images` list to your `ansible/vars/sync-operator-index.yml` file:

```yaml
# Sync extra container images directly (without renaming) into the destination registry.
additional_images:
- quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z
- quay.io/namespace/image_name:example_tag
```

> [!NOTE]
> The `additional_images` parameter mirrors the images exactly as they are named. It does not support renaming the target destination path or tag. Images requiring a rename must still be mirrored manually using `oc image mirror`.

**Automating Image Mirroring with Renaming**

Instead of manually running `oc image mirror` commands, you can automate mirroring generic container images into your bastion registry during the `sync-operator-index` playbook execution. This method uses a separate background task to process and mirror the images, ensuring it fully supports renaming the target destination path.

Simply add the `extra_images` list to your `ansible/vars/sync-operator-index.yml` file:

```yaml
# Sync extra container images using oc image mirror, which allows renaming.
extra_images:
- src: registry.redhat.io/openshift4/ztp-site-generate-rhel8:v4.21.0-2
  dest: openshift-kni/ztp-site-generator:v4.21.0-2
- src: quay.io/minio/minio:RELEASE.2025-09-07T16-13-09Z
  dest: minio/minio:RELEASE.2025-09-07T16-13-09Z
```

**Automating ImageTagMirrorSet (ITMS) Creation**

When working in disconnected environments, some core pods or debugging tools may have external registry paths hardcoded (e.g., `registry.redhat.io/rhel9/support-tools`). To ensure these pods can pull images from your bastion registry without modifying their manifests, Jetlag can automatically create `ImageTagMirrorSet` (ITMS) resources during the post-cluster-install phase.

Simply add the `image_tag_mirrors` list to your `ansible/vars/all.yml` file. This tells OpenShift to intercept requests to the `source` registry and redirect them to your local bastion registry under the `dest` namespace.

```yaml
# Automatically generate ITMS resources post-install
# The destination will automatically point to your bastion: <registry_host>:<registry_port>/<dest>
image_tag_mirrors:
- source: registry.redhat.io/rhel9
  dest: rhel9
```

## Bandwidth limiting

The `bastion-registry-bandwidth.yml` playbook applies bandwidth limits to the bastion mirror registry using Linux traffic control (`tc`). It uses HTB (Hierarchical Token Bucket) with port-targeted filters so that **only registry traffic (port 5000) is shaped** — SSH, DNS, assisted-installer API, HTTP, and other bastion services remain unaffected.

This is useful for simulating constrained WAN links in disconnected environments without tearing down pods or restarting services. Limits can be applied and removed at any time while the registry is running.

> [!WARNING]
> The first run of this playbook installs `iproute-tc` and `kernel-modules-extra` packages. Installing `kernel-modules-extra` requires a reboot of the bastion machine. Subsequent runs will not require a reboot. Plan accordingly.

### Setup

```console
(.ansible) [root@<bastion> jetlag]# cp ansible/vars/registry-bandwidth.sample.yml ansible/vars/registry-bandwidth.yml
(.ansible) [root@<bastion> jetlag]# vi ansible/vars/registry-bandwidth.yml
```

### Variables

| Variable                       | Default  | Description                                              |
| ------------------------------ | -------- | -------------------------------------------------------- |
| `install_tc`                   | `true`   | Install tc packages on the bastion if not already present |
| `apply_registry_egress_limit`  | `true`   | Apply outbound (bastion -> nodes) bandwidth limit        |
| `apply_registry_ingress_limit` | `true`   | Apply inbound (nodes -> bastion) bandwidth limit         |
| `registry_egress_bandwidth`    | `100000` | Egress bandwidth in kbit/s (100000 = 100 Mbps)          |
| `registry_ingress_bandwidth`   | `100000` | Ingress bandwidth in kbit/s (100000 = 100 Mbps)         |
| `registry_bw_port`             | `5000`   | Registry port to shape (must match `registry_port`)      |
| `registry_bw_interface`        | `bastion_controlplane_interface` | Network interface to shape |

### Apply bandwidth limits

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-registry-bandwidth.yml
```

### Remove bandwidth limits

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-registry-bandwidth.yml -e 'apply_registry_egress_limit=false apply_registry_ingress_limit=false'
```

### Override bandwidth at runtime

```console
(.ansible) [root@<bastion> jetlag]# ansible-playbook -i ansible/inventory/cloud99.local ansible/bastion-registry-bandwidth.yml -e 'registry_egress_bandwidth=50000 registry_ingress_bandwidth=50000'
```

> [!NOTE]
> The playbook is idempotent — it always removes existing shaping rules before applying new ones. You can re-run it with different bandwidth values without first removing the previous limits.

### Verifying bandwidth limits

After applying limits, you can verify the tc shaping rules directly on the bastion:

```console
(.ansible) [root@<bastion> jetlag]# tc qdisc show dev ens1f0
qdisc htb 1: root refcnt 113 r2q 10 default 0x10 direct_packets_stat 0 direct_qlen 1000
qdisc ingress ffff: parent ffff:fff1 ----------------

(.ansible) [root@<bastion> jetlag]# tc class show dev ens1f0
class htb 1:10 root prio 0 rate 10Gbit ceil 10Gbit burst 0b cburst 0b
class htb 1:20 root prio 0 rate 100Mbit ceil 100Mbit burst 1600b cburst 1600b

(.ansible) [root@<bastion> jetlag]# tc qdisc show dev ifb0
qdisc htb 1: root refcnt 2 r2q 10 default 0x10 direct_packets_stat 0 direct_qlen 32

(.ansible) [root@<bastion> jetlag]# tc class show dev ifb0
class htb 1:10 root prio 0 rate 10Gbit ceil 10Gbit burst 0b cburst 0b
class htb 1:20 root prio 0 rate 100Mbit ceil 100Mbit burst 1600b cburst 1600b
```

Class `1:10` is the unlimited default for all non-registry traffic. Class `1:20` is the rate-limited class for registry port traffic — in this example capped at 100 Mbit. Replace `ens1f0` with your `bastion_controlplane_interface`.

To confirm the limit is actively throttling, pull a large image from the registry on a separate machine (e.g. a cluster node or another host in the lab) and observe the transfer speed:

```console
[root@<worker> ~]# podman pull --creds "registry:registry" docker://<bastion>:5000/openshift-kni/ocp-ibu:4.22.0-rc.3.ibu-x86_64
Trying to pull <bastion>:5000/openshift-kni/ocp-ibu:4.22.0-rc.3.ibu-x86_64...
Getting image source signatures
Copying blob fb7080fbded5 [>-------------------------------------] 28.5MiB / 1.4GiB | 11.2 MiB/s
```

With a 100 Mbps limit you should see transfer speeds around ~11-12 MiB/s. Any large image in the registry works for this test — IBU seed images (~1.4 GiB) make the throttling especially obvious.

> [!TIP]
> If retesting, remove the previously pulled image first (`podman rmi <image>`) so that podman performs a full download rather than using cached layers.
