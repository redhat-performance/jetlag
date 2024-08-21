# Troubleshooting Jetlag

_**Table of Contents**_

<!-- TOC -->
- [Common Issues](#common-issues)
  - [Running Jetlag after Jetski](#running-jetlag-after-jetski)
  - [Failed on Wait up to 40 min for nodes to be discovered](#failed-on-wait-up-to-40-min-for-nodes-to-be-discovered)
  - [Intermittent failures by repos or container registry](#intermittent-failures-by-repos-or-container-registry)
  - [Root disk too small on bastion](#root-disk-too-small-on-bastion)
- [Bastion](#bastion)
  - [Accessing services](#accessing-services)
  - [Clean all container services / podman pods](#clean-all-container-services--podman-pods)
  - [Clean all container images from bastion registry](#clean-all-container-images-from-bastion-registry)
  - [Rebooted Bastion](#rebooted-bastion)
  - [ipv4 to ipv6 deployed cluster and vice-versa](#ipv4-to-ipv6-deployed-cluster)
- [Generic Hardware](#generic-hardware)
  - [Minimum Firmware Versions](#minimum-firmware-versions)
- [Dell](#dell)
  - [Reset BMC / iDrac](#reset-bmc--idrac)
  - [Unable Mount Virtual Media](#unable-mount-virtual-media)
- [Supermicro](#supermicro)
  - [Reset BMC / Resolving redfish connection error](#reset-bmc--resolving-redfish-connection-error)
  - [Missing Administrator IPMI privileges](#missing-administrator-ipmi-privileges)
  - [Failure of TASK SuperMicro Set Boot](#failure-of-task-supermicro-set-boot)
- [Generic Lab](#generic-lab)
  - [Boot mode](#boot-mode)
  - [Lab network pre-configuration](#network-pre-configuration)
- [Scalelab](#scalelab)
  - [Fix boot order of machines](#fix-boot-order-of-machines)
  - [Upgrade RHEL](#upgrade-rhel)
<!-- /TOC -->

# Common Issues

## Running Jetlag after Jetski

If Jetlag is run after attempting an installation with Jetski, there are several configuration items that are known to conflict and prevent successful install:

* Polluted dnsmasq configuration and dns services (depending on if jetlag ran dnsmasq or coredns)
* The Jetski configured virtual bridge network could cause additional networking headaches preventing successful install

That may not be all of the conflicts, thus the preferred method to remediate this situation is to cleanly rebuild the RHEL OS running on the bastion machine for Jetlag.

## Failed on Wait up to 40 min for nodes to be discovered

If the playbook failed on the task [Wait up to 40 min for nodes to be discovered](https://github.com/redhat-performance/jetlag/blob/main/ansible/roles/wait-hosts-discovered/tasks/main.yml#L14) then open the assisted-installer gui page (http://$BASTION:8080) and see if any of the cluster's machines were discovered. If the intended cluster is a multi-node OpenShift cluster and zero nodes were discovered, then likely there is an issue with the network setup. The next step would be to confirm if the machines are reachable over the intended network using (ping and ssh). If they are not, then reconfirm the correct values for the following vars:

```
bastion_lab_interface
bastion_controlplane_interface
controlplane_lab_interface
```

If the machines are reachable, but never registered with the assisted-installer, then check if the assisted-installer-agent container image was pulled and running. You can inspect journal logs to see if this occurred. Possible failures or misconfiguration preventing progress here could be incorrect dns, bad pull-secret, or NAT on bastion is incorrect and not forwarding traffic.

If some nodes correctly registered but some did not, then the missing nodes need to be individually diagnosed. On a missing node, check if the BMC actually mounted the virtual media. Typically the machine just requires a BMC reset due to not booting virtual media which is described in below sections. Another possibility includes non-functional hardware and thus the machine does not boot into the discovery image.

## Intermittent failures by repos or container registry

Since Jetlag has external dependencies on repos available by your machines as well as container images hosted in a container registry, it is possible that an intermittent failure, service outage, or network failure can cause a failed deployment. Check that your machines have working repository server configurations and that container registries in use are not experiencing an outage.  For example quay and Red Hat repos provide a public status check [status.redhat.com](https://status.redhat.com/)

## Root disk too small on bastion

For disconnected environments, the bastion machine will serve all OCP, operator and additional container images from its local disconnected registry. Some machines in the lab have been found to have root disks which are on the order of only 70G and can easily fill with 1 or 2 OCP releases synced. If the bastion is one of those machines, relocate `/opt` to a separate larger disk so the machine does not run out of space on the root disk.

# Bastion

## Accessing services

Several services are run on the bastion in order to automate the tasks that Jetlag performs. You can access them via the following ports:

| Service | Port |
| - | - |
| On-prem `assisted-installer` GUI | 8080
| On-prem `assisted-installer` API | 8090
| On-prem `assisted-image-service` | 8888
| HTTP server | 8081
| Container Registry (When `setup_bastion_registry=true`) | 5000
| HAProxy (When disconnected) | 6443, 443, 80
| Gogs - Self-hosted Git (When `setup_bastion_gogs=true`) | 10881 (http), 10022 (git)
| Dnsmasq / Coredns | 53

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

## Unable Mount Virtual Media

In some cases, the Dell iDRAC is unable to mount Virtual Media due to the Virtual Console Plug-in Type being set as eHTML5 instead of HTML5.
To change this, navigate to Configuration -> Virtual Console -> Plug-in Type and select HTML5 instead of eHTML5.

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
 User ID | User Name       | Privilege Level    | Enable
 ------- | -----------     | ---------------    | ------
       3 | root            | Operator           | Yes

[root@<bastion> ~]# SMCIPMITool y.y.y.y root yyyyyyyy user list
Maximum number of Users          : 10
Count of currently enabled Users : 8
 User ID | User Name       | Privilege Level    | Enable
 ------- | -----------     | ---------------    | ------
       2 | ADMIN           | Administrator      | Yes
       3 | root            | Administrator      | Yes
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

# Generic Lab

## Boot mode

In the Performance lab working with Dell machines, the boot mode of the nodes where OCP should be installed should be set to **UEFI** regardless of BM or SNO cluster types. In the Scale lab there is no evidence of this issue, the machines are usually delivered with the **BIOS** mode set. This can be easily done with badfish:

```console
badfish -H mgmt-<fqdn> -u user -p password --set-bios-attribute --attribute BootMode --value Uefi
```

Symptoms to look for: The OCP installation will successfully write the RHEL CoreOS image to the node and boot it up, where the node will be discovered by the bastion. In the virtual console of the management interface during the booting step, you can see a banner indicating *virtual media*. However, the following steps, where the OCP installation happens, will fail with a jetlag retry timeout with an error similar to:

```
Expected the host to boot from disk, but it booted the installation image - please reboot and fix boot order to boot from disk ...
```

Other things to look at:

1) Check the disk name (default in Jetlag is /dev/sda, but it could be sdb, sdl, etc.), depending on how the machine's disks are configured. Verify where OCP is being installed and booted up compared to jetlag's default disk name.

2) Did the machine boot the virtual media (management interface, i.e., iDRAC for Dell machines)?
If the virtual media did not boot, it is most likely a *boot order* issue.
Three other things to consider, however less common, are: 1) An old firmware that requires an iDRAC/BMC reset, 2) the DNS settings in the BMC cannot resolve the bastion, and 3) Check for subnet address collision in your local inventory file.

## Network pre-configuration

You may receive machines from the lab team with some pre-assigned IP addresses, e.g., 198.xx.
Before the OCP install and any boot order changes, ssh on the machines to nuke these IP addresses with the script *clean-interfaces.sh*.


# Scalelab

## Fix boot order of machines

If a machine needs to be rebuilt in the Scale Lab and refuses to correctly rebuild, it is likely a boot order issue. Using badfish, you can correct boot order issues by performing the following:

> [!NOTE]
> The process for the Performance Lab is similar, however the GitLab `config/idrac_interfaces.yml`
> is specialized for the Scale Lab configurations, and needs to be modified for Performance Lab. The
> necessary modifications are not covered here.

```console
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --boot-to-type foreman
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --check-boot
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --power-cycle
```

Substitute the user/password/hostname to allow the boot order to be fixed on the host machine. Note it will take a few minutes before the machine should reboot. If you previously triggered a rebuild, the machine will likely go straight into rebuild mode afterwards. You can learn more about [badfish here](https://github.com/redhat-performance/badfish).

Note that with badfish this is a one time operation, i.e., the boot order after a rebuild/reboot will return to the original value.

Also, watch for the output of **--boot-to-type foreman**, because the correct boot order is different for Scale vs Performance lab.
The values in *config/idrac_interfaces.yml* are first of all for the Scale lab.

```console
[user@<local> badfish]$ ./src/badfish/badfish.py -H mgmt-computer.example.com -u user -p password -i config/idrac_interfaces.yml -t foreman
- INFO     - Job queue for iDRAC mgmt-computer.example.com successfully cleared.
- INFO     - PATCH command passed to update boot order.
- INFO     - POST command passed to create target config job.
- INFO     - Command passed to ForceOff server, code return is 204.
- INFO     - Polling for host state: Not Down
- POLLING: [------------------->] 100% - Host state: On
- INFO     - Command passed to On server, code return is 204.
```
## Upgrade RHEL

> [!TIP]
> This applies to Scale lab and Performance lab.

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
