# Troubleshooting Jetlag

_**Table of Contents**_

<!-- TOC -->
- [Troubleshooting Jetlag](#troubleshooting-jetlag)
- [Common Issues](#common-issues)
  - [Running Jetlag after Jetski](#running-jetlag-after-jetski)
  - [Ingress vip already in use](#ingress-vip-already-in-use)
  - [Intermittent failures by repos or container registry](#intermittent-failures-by-repos-or-container-registry)
  - [Failed on Wait up to 40 min for nodes to be discovered](#failed-on-wait-up-to-40-min-for-nodes-to-be-discovered)
  - [Failed on Wait for cluster to be ready](#failed-on-wait-for-cluster-to-be-ready)
  - [Failed on Adjust by-path selected install disk](#failed-on-adjust-by-path-selected-install-disk)
- [Bastion](#bastion)
  - [Accessing services](#accessing-services)
  - [Clean all container services / podman pods](#clean-all-container-services--podman-pods)
  - [Clean all container images from bastion registry](#clean-all-container-images-from-bastion-registry)
  - [Rebooted Bastion](#rebooted-bastion)
  - [Incorrect bastion controlplane interface](#incorrect-bastion-controlplane-interface)
  - [Changed controlplane network on bastion](#changed-controlplane-network-on-bastion)
  - [Root disk too small](#root-disk-too-small)
- [Generic Hardware](#generic-hardware)
  - [Minimum Firmware Versions](#minimum-firmware-versions)
- [Dell](#dell)
  - [Reset BMC / iDRAC](#reset-bmc--idrac)
  - [Unable to Insert/Mount Virtual Media](#unable-to-insertmount-virtual-media)
- [Supermicro](#supermicro)
  - [Reset BMC / Resolving redfish connection error](#reset-bmc--resolving-redfish-connection-error)
  - [Missing Administrator IPMI privileges](#missing-administrator-ipmi-privileges)
  - [Failure of TASK Supermicro Set Boot](#failure-of-task-supermicro-set-boot)
- [Red Hat Labs](#red-hat-labs)
  - [Fix boot order of machines](#fix-boot-order-of-machines)
  - [Upgrade RHEL](#upgrade-rhel)
<!-- /TOC -->

# Common Issues

## Running Jetlag after Jetski

If Jetlag is run after attempting an installation with Jetski, there are several configuration items that are known to conflict and prevent successful install:

* Polluted dnsmasq configuration and dns services (depending on if jetlag ran dnsmasq or coredns)
* The Jetski configured virtual bridge network could cause additional networking headaches preventing successful install

That may not be all of the conflicts, thus the preferred method to remediate this situation is to cleanly rebuild the RHEL OS running on the bastion machine for Jetlag.

## Ingress vip already in use

When redeploying Jetlag in a cloud allocation where Jetlag was previously deployed it is recommended to shut down all the nodes of the allocation (except the bastion server).

This is to avoid errors on the ***wait-hosts-discovered : Patch cluster ingress/api vip addresses*** task, i.e.:
```
ingress-vip <x.y.z.w> is already in use in cidr x.y.z.w/z
```

This error occurs (specially when changing the cluster size of the environment) because the  previously deployed cluster has some remaining nodes online and thus the "old" cluster's API VIP is still responsive.

## Intermittent failures by repos or container registry

Since Jetlag has external dependencies on repos available by your machines as well as container images hosted in a container registry, it is possible that an intermittent failure, service outage, or network failure can cause a failed deployment. Check that your machines have working repository server configurations and that container registries in use are not experiencing an outage. For example quay and Red Hat repos provide a public status check [status.redhat.com](https://status.redhat.com/)

## Failed on Wait up to 40 min for nodes to be discovered

If the playbook failed on the task [Wait up to 40 min for nodes to be discovered](https://github.com/redhat-performance/jetlag/blob/main/ansible/roles/wait-hosts-discovered/tasks/main.yml#L20) then open the assisted-installer gui page (http://$BASTION:8080) and see if any of the cluster's machines were discovered. If the intended cluster is a multi-node OpenShift cluster and zero nodes were discovered, then likely there is an issue with the network setup. The next step would be to confirm if the machines are reachable over the intended network using (ping and ssh). If they are not, then reconfirm the correct values for the following vars:

```
bastion_lab_interface
bastion_controlplane_interface
controlplane_lab_interface
```

If the machines are reachable, but never registered with the assisted-installer, then check if the assisted-installer-agent container image was pulled and running. You can inspect journal logs to see if this occurred. Possible failures or misconfiguration preventing progress here could be incorrect dns, bad pull-secret, or NAT on bastion is incorrect and not forwarding traffic.

If some nodes correctly registered but some did not, then the missing nodes need to be individually diagnosed. On a missing node, check if the BMC actually mounted the virtual media. Typically the machine just requires a BMC reset due to not booting virtual media which is described in below sections. Another possibility includes non-functional hardware and thus the machine does not boot into the discovery image.

## Failed on Wait for cluster to be ready

Check the "View cluster events" on the assisted-installer GUI to see if any validations
are failing. If you see `Host xxxxx: validation sufficient-packet-loss-requirement-for-role that used to succeed is now failing`
the most likely situation is a duplicate IP on the network causing packet loss. Check
your environment and inventory file for any machines which may have a duplicated ip
address.

If the cluster events shows `Cluster validation 'machine-cidr-defined' failed` or `Cluster validation 'machine-cidr-equals-to-calculated-cidr' failed` then it is likely the `controlplane_network` had been changed and the previous IP address had not been removed off the bastion's `bastion_controlplane_interface`.

For Example:

```console
# ip a show ens2f0
4: ens2f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether b4:83:51:0b:bb:2e brd ff:ff:ff:ff:ff:ff
    altname enp139s0f0
    inet 198.18.10.1/24 brd 198.18.10.255 scope global noprefixroute ens2f0
       valid_lft forever preferred_lft forever
    inet 198.18.0.1/16 brd 198.18.255.255 scope global noprefixroute ens2f0
       valid_lft forever preferred_lft forever
    inet6 fe80::b683:51ff:fe0b:bb2e/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

We can see two IP addresses on `ens2f0` which in this case is the bastion's `bastion_controlplane_interface`. The default `controlplane_network` is `198.18.0.0/16` so we need to remove `198.18.10.1/24`:

```console
# ip a del 198.18.10.1/24 dev ens2f0
```

After removing the extra IP address, we can rerun a deployment and the cluster will succeed. Additionally, you should investigate what occured to lead up to accidently causing an extra IP address to be assigned to your bastion's `bastion_controlplane_interface`. The most likely reason is either upgrading or downgrading jetlag versions or changing your `controlplane_network` without removing the previous IP addresses.

## Failed on Adjust by-path selected install disk

In rare cases, jetlag is unable to set the install disk because there are leftover cruft
partitions on the intended install disk that tricks assisted installer into believing the
entire disk is an ISO or CD partition. The cruft partitions appear to survive a foreman
rebuild and thus a more robust method of wiping is required while the node is booted from
a discovery.iso or another LiveCD. The jetlag error you will see resembles:

```console
TASK [wait-hosts-discovered : Adjust by-path selected install disk] ************
Tuesday 21 January 2025  22:00:02 +0000 (0:00:00.062)       0:15:26.342 *******
fatal: [example.com]: FAILED! => {"changed": false, "connection": "close", "content": "{\"code\":\"409\",\"href\":\"\",\"id\":409,\"kind\":\"Error\",\"reason\":\"Requested installation disk is not part of the host's valid disks\"}\n", "content_length": "126", "content_type": "application/json", "date": "Tue, 21 Jan 2025 22:00:02 GMT", "elapsed": 0, "json": {"code": "409", "href": "", "id": 409, "kind": "Error", "reason": "Requested installation disk is not part of the host's valid disks"}, "msg": "Status code was 409 and not [201]: HTTP Error 409: Conflict", "redirected": false, "status": 409, "url": "http://example.com:8090/api/assisted-install/v2/infra-envs/2ba94792-10cc-41a0-a4c4-ba571d2acd1f/hosts/4108df44-c238-f427-77ff-64553785e097", "vary": "Accept-Encoding"}
```

You will also see in the assisted-installer GUI on an affected machine there is a
limitation next to the intended install disk that displays
`Disk is not eligible for installation. Disk appears to be an ISO installation media (has partition with type iso9660)`.
In this case we can reuse the current booted discovery.iso to verify and wipe the cruft
off the intended installation media to resolve this issue:

```console
[root@bastion ~]# ssh core@198.18.10.20
...
[core@localhost ~]$ sudo su -
...
[root@localhost ~]# lsblk
NAME                               MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0                                7:0    0 251.7G  0 loop /var/lib/containers/storage/overlay
                                                             /var
                                                             /etc
                                                             /run/ephemeral
loop1                                7:1    0   1.1G  1 loop /usr
                                                             /boot
                                                             /
                                                             /sysroot
sda                                  8:0    0 447.1G  0 disk
├─sda1                               8:1    0     1M  0 part
├─sda2                               8:2    0     1M  0 part
├─sda3                               8:3    0   512M  0 part
├─sda4                               8:4    0     1K  0 part
└─sda5                               8:5    0 446.6G  0 part
  ├─vg_d27--h31--000--r650-lv_swap 253:0    0     8G  0 lvm
  └─vg_d27--h31--000--r650-lv_root 253:1    0 438.6G  0 lvm
sdb                                  8:16   0   1.7T  0 disk
sdc                                  8:32   0   1.7T  0 disk
sr0                                 11:0    1   1.2G  0 rom  /run/media/iso
nvme0n1                            259:0    0   2.9T  0 disk
[root@localhost ~]# file -Ls /dev/sda1
/dev/sda1: ISO 9660 CD-ROM filesystem data 'config-2'
```

Here we can see parition `/dev/sda1` is formated as an ISO 9660 CD-ROM and the cause of
this issue. Depending on hardware this could actually be a different symbolic link. In
order to resolve this we will wipe the disk by executing the following commands:

```console
[root@localhost ~]# vgs
  VG                  #PV #LV #SN Attr   VSize   VFree
  vg_d27-h31-000-r650   1   2   0 wz--n- 446.62g    0
[root@localhost ~]# vgremove vg_d27-h31-000-r650
Do you really want to remove active logical volume vg_d27-h31-000-r650/lv_swap? [y/n]: y
  Logical volume "lv_swap" successfully removed.
Do you really want to remove active logical volume vg_d27-h31-000-r650/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed.
  Volume group "vg_d27-h31-000-r650" successfully removed
[root@localhost ~]# vgs
[root@localhost ~]# pvs
  PV         VG Fmt  Attr PSize    PFree
  /dev/sda5     lvm2 ---  <446.63g <446.63g
[root@localhost ~]# pvremove /dev/sda5
  Labels on physical volume "/dev/sda5" successfully wiped.
[root@localhost ~]# pvs
[root@localhost ~]# lsblk
NAME    MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0     7:0    0 251.7G  0 loop /var/lib/containers/storage/overlay
                                  /var
                                  /etc
                                  /run/ephemeral
loop1     7:1    0   1.1G  1 loop /usr
                                  /boot
                                  /
                                  /sysroot
sda       8:0    0 447.1G  0 disk
├─sda1    8:1    0     1M  0 part
├─sda2    8:2    0     1M  0 part
├─sda3    8:3    0   512M  0 part
├─sda4    8:4    0     1K  0 part
└─sda5    8:5    0 446.6G  0 part
sdb       8:16   0   1.7T  0 disk
sdc       8:32   0   1.7T  0 disk
sr0      11:0    1   1.2G  0 rom  /run/media/iso
nvme0n1 259:0    0   2.9T  0 disk
[root@localhost ~]# wipefs -f -a /dev/sda
/dev/sda: 2 bytes were erased at offset 0x000001fe (dos): 55 aa
```

Now the disk is wiped of the cruft partition. You can now retry a new deployment to verify this machine is now installable.

# Bastion

## Accessing services

Several services are run on the bastion in order to automate the tasks that Jetlag performs. You can access them via the following ports:

| Service                                                 | Port                      |
| ------------------------------------------------------- | ------------------------- |
| On-prem `assisted-installer` GUI                        | 8080                      |
| On-prem `assisted-installer` API                        | 8090                      |
| On-prem `assisted-image-service`                        | 8888                      |
| HTTP server                                             | 8081                      |
| Container Registry (When `setup_bastion_registry=true`) | 5000                      |
| HAProxy (When disconnected)                             | 6443, 443, 80             |
| Gogs - Self-hosted Git (When `setup_bastion_gogs=true`) | 10881 (http), 10022 (git) |
| Dnsmasq / Coredns                                       | 53                        |

Example accessing the bastion registry and listing repositories:
```console
(.ansible) [root@<bastion> jetlag]# curl -u registry:registry -k https://<bastion>:5000/v2/_catalog?n=100 | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   532  100   532    0     0    104      0  0:00:05  0:00:05 --:--:--   120
{
  "repositories": [
    "edge-infrastructure/assisted-image-service",
    "edge-infrastructure/assisted-installer",
    "edge-infrastructure/assisted-installer-agent",
    "edge-infrastructure/assisted-installer-controller",
    "edge-infrastructure/assisted-installer-ui",
    "edge-infrastructure/assisted-service",
    "edge-infrastructure/postgresql-12-centos7",
    "ocp4/openshift4",
    "olm-mirror/redhat-operator-index",
    "openshift4/ose-local-storage-diskmaker",
    "openshift4/ose-local-storage-operator",
    "openshift4/ose-local-storage-operator-bundle",
    "openshift4/ose-local-storage-static-provisioner"
  ]
}
```

## Clean all container services / podman pods

In the event your bastion's running containers have incorrect data or you are deploying a new OCP version and need to remove the containers in order to rerun the `setup-bastion.yml` playbook.

Clean **all** containers (on bastion machine):

```console
podman ps | awk '{print $1}' | xargs -I % podman stop %; podman ps -a | awk '{print $1}' | xargs -I % podman rm %; podman pod ps | awk '{print $1}' | xargs -I % podman pod rm %
```

When replacing the ocp version, just remove the assisted-installer pod and container, then rerun the `setup-bastion.yml` playbook.

## Clean all container images from bastion registry

If you are planning a redeploy with new versions and new container images it may make sense to clean all the old container images to start fresh. First [clean the pods and containers off the bastion following this](troubleshooting.md#clean-all-container-services--podman-pods). Then remove the directory containing the images.

On the bastion machine:

```console
(.ansible) [root@<bastion> jetlag]# cd /opt/registry
(.ansible) [root@<bastion> registry]#
(.ansible) [root@<bastion> registry]# ls -lah
total 12K
drwxr-xr-x. 6 root root  144 Jul 20 12:14 .
drwxr-xr-x. 6 root root   83 Jul 16 15:01 ..
drwxr-xr-x. 2 root root   22 Jul 20 02:27 auth
drwxr-xr-x. 2 root root   42 Jul 20 02:27 certs
drwxr-xr-x. 3 root root   20 Jul 20 02:27 data
-rwxr--r--. 1 root root  714 Jul 20 02:27 generate-cert.sh
-rw-r--r--. 1 root root 3.0K Jul 20 20:31 pull-secret-bastion.txt
-rw-r--r--. 1 root root 2.9K Jul 20 02:27 pull-secret.txt
drwxr-xr-x. 2 root root  191 Jul 21 12:26 sync-acm-d
(.ansible) [root@<bastion> registry]# du -sh *
4.0K    auth
8.0K    certs
27G     data
4.0K    generate-cert.sh
4.0K    pull-secret-bastion.txt
4.0K    pull-secret.txt
48K     sync-acm-d
(.ansible) [root@<bastion> registry]# rm -rf data/docker/
```

## Rebooted Bastion

If the bastion has been rebooted, you may experience ImagePullBackOff on containers and or other issues related to your cluster no longer being able to reach the internet and associated image repositories (Or your disconnected registry). In order to re-establish connectivity and bastion services, do the following:

* [Clean all container services / podman pods](troubleshooting.md#clean-all-container-services--podman-pods)
* Rerun the setup-bastion.yml playbook

## Incorrect bastion controlplane interface

If the incorrect `bastion_controlplane_interface` was configured, you can remedy this by
using NetworkManager CLI (`nmcli`).

In the below example, `ens2f1` was incorrectly set as the
`bastion_controlplane_interface`, and can be fixed by applying the correct ip address to
`ens1f0`, the correct interface for an r650.

```console
# ip a show ens2f1
8: ens2f1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 08:c0:eb:ad:33:31 brd ff:ff:ff:ff:ff:ff
    altname enp152s0f1
    inet 198.18.0.1/16 brd 198.18.255.255 scope global noprefixroute ens2f1
       valid_lft forever preferred_lft forever
    inet6 fe80::5b87:8ca3:1a7f:2450/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
# nmcli c
NAME                UUID                                  TYPE      DEVICE
eno12399np0         5da5d1e4-e608-86ee-04c4-28f6e7b3513c  ethernet  eno12399np0
cni-podman0         0aba285f-4713-4337-a6e1-f448dd0cc934  bridge    cni-podman0
eno12409np1         d64216ea-ca07-4730-9fce-e74d191bde0a  ethernet  eno12409np1
ens2f1              49fab00e-5bfd-45a8-b463-0085b1239cb9  ethernet  ens2f1
Wired connection 1  bcc54b47-9a50-3be1-9b95-3d68aeee31f8  ethernet  ens2f0
Wired connection 3  a6cdebcb-50da-314a-bbd4-11fbdefbc34c  ethernet  ens1f1
eno8303             25c28842-d9fb-4f47-93ce-abacb899865f  ethernet  --
eno8403             abadc7d9-f4be-4544-816e-ac46e3839d30  ethernet  --
# nmcli c delete ens2f1
Connection 'ens2f1' (49fab00e-5bfd-45a8-b463-0085b1239cb9) successfully deleted.
# nmcli c
NAME                UUID                                  TYPE      DEVICE
eno12399np0         5da5d1e4-e608-86ee-04c4-28f6e7b3513c  ethernet  eno12399np0
cni-podman0         0aba285f-4713-4337-a6e1-f448dd0cc934  bridge    cni-podman0
eno12409np1         d64216ea-ca07-4730-9fce-e74d191bde0a  ethernet  eno12409np1
Wired connection 1  bcc54b47-9a50-3be1-9b95-3d68aeee31f8  ethernet  ens2f0
Wired connection 3  a6cdebcb-50da-314a-bbd4-11fbdefbc34c  ethernet  ens1f1
eno8303             25c28842-d9fb-4f47-93ce-abacb899865f  ethernet  --
eno8403             abadc7d9-f4be-4544-816e-ac46e3839d30  ethernet  --
# nmcli con add con-name "ens1f0" ifname ens1f0 type ethernet ip4 198.18.0.1/16
Connection 'ens1f0' (7d0ffc4e-ef0e-40e4-a3c7-4baaa045d01c) successfully added.
# nmcli c
NAME                UUID                                  TYPE      DEVICE
...
ens1f0              7d0ffc4e-ef0e-40e4-a3c7-4baaa045d01c  ethernet  ens1f0
...
```

## Changed controlplane network on bastion

If you changed the subnet with the var `controlplane_network`, you will have to remove
the previous ip address with `ip a del`

```console
# ip a show ens1f0
7: ens1f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether b4:96:91:cb:ec:1e brd ff:ff:ff:ff:ff:ff
    altname enp75s0f0
    inet 198.18.10.1/24 brd 198.18.10.255 scope global noprefixroute ens1f0
       valid_lft forever preferred_lft forever
    inet 198.18.0.1/16 brd 198.18.255.255 scope global noprefixroute ens1f0
       valid_lft forever preferred_lft forever
    inet6 fc00:1005::1/64 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::84fa:3366:be96:72a4/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
# ip a del 198.18.10.1/24 dev ens1f0
# ip a show ens1f0
7: ens1f0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether b4:96:91:cb:ec:1e brd ff:ff:ff:ff:ff:ff
    altname enp75s0f0
    inet 198.18.0.1/16 brd 198.18.255.255 scope global noprefixroute ens1f0
       valid_lft forever preferred_lft forever
    inet6 fc00:1005::1/64 scope global noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::84fa:3366:be96:72a4/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
```

> [!TIP]
> It is possible to have both ipv4 and ipv6 configured as shown above

## Root disk too small

For disconnected environments, the bastion machine will serve all OCP, operator and
additional container images from its local disconnected registry. Some machines in the
lab have been found to have root disks which are on the order of only 70G and can fill
with 1 or 2 OCP releases synced. If the bastion is one of those machines, relocate `/opt`
to a separate larger disk so the machine does not run out of space on the root disk.

# Generic Hardware

## Minimum Firmware Versions

Review the [OpenShift documentation to understand what minimum firmware versions are required](https://docs.openshift.com/container-platform/4.14/installing/installing_bare_metal_ipi/ipi-install-prerequisites.html#ipi-install-firmware-requirements-for-installing-with-virtual-media_ipi-install-prerequisites) for HP and Dell hardware  based clusters to be deployed via Redfish virtual media.

# Dell

## Reset BMC / iDRAC

In some cases the Dell iDRAC might need to be reset per host. This can be done with the following command:

```console
sshpass -p "password" ssh -o StrictHostKeyChecking=no user@mgmt-computer.example.com "racadm racreset"
```

Substitute the user/password/hostname to perform the reset on a desired host. Note it will take a few minutes before the BMC will become available again.

> [!CAUTION]
> A Factory reset is not the same as a BMC reset or iDRAC reboot. Do not factory reset your machines.

## Unable to Insert/Mount Virtual Media

There have been cases where specific versions of iDrac produce an error message resembling:

```console
TASK [boot-iso : DELL - Insert Virtual Media] *********************************************************************************************************************************************************************
Tuesday 21 January 2025  00:34:48 +0000 (0:00:00.024)       0:04:10.771 *******
fatal: [example.com]: FAILED! => {"changed": false, "msg": "HTTP Error 400 on POST request to 'https://example.com/redfish/v1/Managers/iDRAC.Embedded.1/VirtualMedia/CD/Actions/VirtualMedia.InsertMedia', extended message: 'Unable to locate the ISO or IMG image file or folder in the network share location because the file or folder path or the user credentials entered are incorrect.'"}
```

In this case the iDrac firmware was the incorrect version. Working version of firmware
has been `7.10.30.00` where as the above error message was produced with versions
`7.10.70.10` and `7.10.50.10`.

Firmware can be checked across many machines by scripting cli commands such as:

```console
echo -n "mgmt-computer.example.com: "; sshpass -p "password" ssh -o StrictHostKeyChecking=no user@mgmt-computer.example.com "racadm getversion" | grep iDRAC
```

In other cases, the Dell iDRAC is unable to mount Virtual Media due to the Virtual
Console Plug-in Type being set as eHTML5 instead of HTML5. To change this, navigate to
Configuration -> Virtual Console -> Plug-in Type and select HTML5 instead of eHTML5.

# Supermicro

## Reset BMC / Resolving redfish connection error

In some cases, issues during a deployment can be the result of a BMC issue. To reset a Supermicro BMC use `ipmitool` with the following example:

```console
ipmitool -I lanplus -H mgmt-computer.example.com -U user -P password mc reset cold
```

The following example errors can be corrected after resetting the BMC of the machines.

```
TASK [boot-iso : SuperMicro - Mount ISO] *****************************************************************************************
Tuesday 05 October 2021  12:20:23 -0500 (0:00:01.256)       0:01:10.117 *******
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool x.x.x.x root xxxxxxxxx wsiso mount \"http://x.x.x.x:8081\" /iso/discovery.iso\n", "delta": "0:00:00.903331", "end": "2021-10-05 12:20:24.841290", "msg": "non-zero return code", "rc": 204, "start": "2021-10-05 12:20:23.937959", "stderr": "", "stderr_lines": [], "stdout": "An ISO file already mounted. Please umount ISO first", "stdout_lines": ["An ISO file already mounted. Please umount ISO first"]}
```

```
Failed GET request to 'https://address.example.com/redfish/v1/Systems/1': 'The read operation timed out'"
```

## Missing Administrator IPMI privileges

Error: The node product key needs to be activated for this device

```
TASK [boot-iso : SuperMicro - Unmount ISO] ***************************************************************************************************************************************************
Thursday 30 September 2021  15:04:14 -0400 (0:00:04.861)       0:01:51.715 ****
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool x.x.x.x root xxxxxxxxx wsiso umount\n", "delta": "0:00:00.857430", "end": "2021-09-30 14:04:15.985123", "msg": "non-zero return code", "rc": 155, "start": "2021-09-30 14:04:15.127693", "stderr": "", "stderr_lines": [], "stdout": "The node product key needs to be activated for this device", "stdout_lines": ["The node product key needs to be activated for this device"]}
```

Error: This device doesn't support WSISO commands

```
TASK [boot-iso : SuperMicro - Unmount ISO] *************************************
Sunday 04 September 2022  15:10:25 -0500 (0:00:03.603)       0:00:21.026 ******
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool 10.220.217.126 root bybdjEBW5y wsiso umount\n", "delta": "0:00:01.319311", "end": "2022-09-04 15:10:27.754259", "msg": "non-zero return code", "rc": 153, "start": "2022-09-04 15:10:26.434948", "stderr": "", "stderr_lines": [], "stdout": "This device doesn't support WSISO commands", "stdout_lines": ["This device doesn't support WSISO commands"]}
```

The permissions of the ipmi/BMC user are likely that of operator and not administrator. Open a case to set ipmi privilege level permissions to administrator. If you have the permissions already set correctly, try to reset BMC [here](#reset-bmc--resolving-redfish-connection-error).

How to verify that ipmi privilege set to administrator level permissions

1. SMCIPMITool:
```console
[root@<bastion> ~]# SMCIPMITool x.x.x.x root xxxxxxxxx user list
Maximum number of Users          : 10
Count of currently enabled Users : 8
 | User ID | User Name | Privilege Level | Enable |
 | ------- | --------- | --------------- | ------ |
 | 3       | root      | Operator        | Yes    |

[root@<bastion> ~]# SMCIPMITool y.y.y.y root yyyyyyyy user list
Maximum number of Users          : 10
Count of currently enabled Users : 8
 | User ID | User Name | Privilege Level | Enable |
 | ------- | --------- | --------------- | ------ |
 | 2       | ADMIN     | Administrator   | Yes    |
 | 3       | root      | Administrator   | Yes    |
```
Machine `y.y.y.y` has the correct permissions.

2. ipmitool:

```console
[root@<bastion> ~]# ipmitool -I lanplus -L ADMINISTRATOR -H <IPMIADDRESS> -p 623 -U root -P <PASSWORD> power status
```

Expected result: Chassis Power is on

## Failure of TASK Supermicro Set Boot

```
The property Boot is not in the list of valid properties for the resource.
```

This is caused by having an older BIOS version.

When set to ignore the error, Jetlag can proceed, but you will need to manually unmount the ISO when the machines reboot the second time (as in not the reboot that happens immediately when Jetlag is run, but the one that happens after a noticeable delay). The unmount must be done as soon as the machines restart, as doing it too early can interrupt the process, and doing it after it boots into the ISO will be too late.

# Red Hat Labs

## Fix boot order of machines

If a machine needs to be rebuilt in the lab and refuses to correctly rebuild, it is likely a boot order issue. Using badfish, you can correct boot order issues by performing the following:

> [!NOTE]
> The process for the Performance Lab is similar, however the GitLab `config/idrac_interfaces.yml`
> is specialized for the Scale Lab configurations, and needs to be modified for Performance Lab. The
> necessary modifications are not covered here.

```console
podman run -it --rm quay.io/quads/badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --boot-to-type foreman
podman run -it --rm quay.io/quads/badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --check-boot
podman run -it --rm quay.io/quads/badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --power-cycle
```

Substitute the user/password/hostname to allow the boot order to be fixed on the host machine. Note it will take a few minutes before the machine should reboot. If you previously triggered a rebuild, the machine will likely go straight into rebuild mode afterwards. You can learn more about [badfish here](https://github.com/redhat-performance/badfish).

Note that with badfish this is a one time operation, i.e., the boot order after a rebuild/reboot will return to the original value.

Also, watch for the output of **--boot-to-type foreman**, because the correct boot order is different for Scale vs Performance lab.
The values in *config/idrac_interfaces.yml* are first of all for the Scale lab.

```console
[user@<local> badfish]$ podman run -it --rm quay.io/quads/badfish -H mgmt-computer.example.com -u user -p password -i config/idrac_interfaces.yml -t foreman
- INFO     - Job queue for iDRAC mgmt-computer.example.com successfully cleared.
- INFO     - PATCH command passed to update boot order.
- INFO     - POST command passed to create target config job.
- INFO     - Command passed to ForceOff server, code return is 204.
- INFO     - Polling for host state: Not Down
- POLLING: [------------------->] 100% - Host state: On
- INFO     - Command passed to On server, code return is 204.
```

## Upgrade RHEL

> [!NOTE]
> Both Scale Lab and Performance Lab ALIAS default to RHEL9.4 now.
>
> This is likely not necessary unless you want to be on a newer U-release of RHEL9

On the bastion machine:

```console
[root@<bastion> ~]# ./update-latest-rhel-release.sh 9.5
Changing repository from 9.4 to 9.5
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 9.5

[root@<bastion> ~]# dnf update -y
...
```

Reboot afterwards and start from the `create-inventory.yml` playbook.
