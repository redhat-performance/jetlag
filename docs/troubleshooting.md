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
  - [Ipv4 to ipv6 deployed cluster](#ipv4-to-ipv6-deployed-cluster)
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
this isse. Depending on hardware this could actually be a different symbolic link. In
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

## Ipv4 to ipv6 deployed cluster

When moving from an ipv4 cluster installation to ipv6 (or vice-versa), instead of rebuilding the bastion with foreman or badfish, use *nmcli* to disable one of the IP addresses. For example, the following commands disable ipv6:

```console
# nmcli c modify ens6f0 ipv6.method "disabled"
# nmcli c show ens6f0
# nmcli c show
# sysctl -p /etc/sysctl.d/ipv6.conf
# vi /etc/sysctl.conf
# sysctl -p /etc/sysctl.d/ipv6.conf
# reboot
```

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

On the bastion machine:

```console
[root@<bastion> ~]# ./update-latest-rhel-release.sh 8.9
Changing repository from 8.2 to 8.9
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 8.9

[root@<bastion> ~]# dnf update -y
...
```

Reboot afterwards and start from the `create-inventory.yml` playbook.
