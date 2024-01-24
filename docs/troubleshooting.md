# Troubleshooting jetlag

_**Table of Contents**_

<!-- TOC -->
- Bastion:
  - [Accessing services](#bastion---accessing-services)
  - [Clean all container services / podman pods](#bastion---clean-all-container-services--podman-pods)
  - [Clean all container images from bastion registry](#bastion---clean-all-container-images-from-bastion-registry)
- Dell:
  - [Reset BMC / iDrac](#dell---reset-bmc--idrac)
  - [Unable Mount Virtual Media](#dell---unable-mount-virtual-media)
- Supermicro:
  - [Reset BMC / Resolving redfish connection error](#supermicro---reset-bmc--resolving-redfish-connection-error)
  - [Missing Administrator IPMI privileges](#supermicro---missing-administrator-ipmi-privileges)
  - [Failure of TASK SuperMicro Set Boot](#supermicro---failure-of-task-supermicro-set-boot)
- Scalelab:
  - [Fix boot order of machines](#scalelab---fix-boot-order-of-machines)
  - [Upgrade RHEL](#scalelab---upgrade-rhel)
- Lab issues and how to go about them
  - [Boot mode](#lab---boot-mode)
  - [Boot order](#lab---boot-order)
  - [Lab network pre-configuration](#lab---network-pre-configuration)
  - [From an ipv4 to ipv6 cluster and vice-versa](#lab---ipv4-to-ipv6-cluster)
<!-- /TOC -->

## Bastion - Accessing services

Several services are run on the bastion in order to automate the tasks that jetlag performs. You can access them via the following ports:

* On-prem assisted-installer GUI - 8080
* On-prem assisted-installer API - 8090
* On-prem assisted-image-service - 8888
* HTTP server - 8081
* Container Registry (When setup_bastion_registry=true) - 5000
* HAProxy (When disconnected) - 6443, 443, 80
* Gogs - Self-hosted Git (When setup_bastion_gogs=true) - 10881 (http), 10022 (git)
* Dnsmasq / Coredns - 53

Examples, change the FQDN to your bastion machine and open in your browser
```
AI Gui - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8080/
AI API - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8090/
HTTP Server - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8081/
```

Example accessing the bastion registry and listing repositories:
```console
[root@f99-h11-000-1029p akrzos]# curl -u registry:registry -k https://f99-h11-000-1029p.rdu2.scalelab.redhat.com:5000/v2/_catalog?n=100 | jq
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

## Bastion - Clean all container services / podman pods

In the event you believe your running containers on the bastion have incorrect data or you are deploying a new OCP version and need to remove the containers in order to rerun the `setup-bastion.yml` playbook.

Clean **all** containers (on your bastion machine):

```console
podman ps | awk '{print $1}' | xargs -I % podman stop %; podman ps -a | awk '{print $1}' | xargs -I % podman rm %; podman pod ps | awk '{print $1}' | xargs -I % podman pod rm %
```

When replacing the ocp version, just remove the assisted-installer pod and container, then rerun the `setup-bastion.yml` playbook.

## Bastion - Clean all container images from bastion registry

If you are planning a redeploy with new versions and new container images it may make sense to clean all the old container images to start fresh. First [clean the pods and containers off the bastion following this](troubleshooting.md#cleaning-all-podscontainers-off-the-bastion-machines). Then remove the directory containing the images.

On the bastion machine:

```console
[root@f16-h11-000-1029p ~]# cd /opt/registry
[root@f16-h11-000-1029p registry]#
[root@f16-h11-000-1029p registry]# ls -lah
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
[root@f16-h11-000-1029p registry]# du -sh *
4.0K    auth
8.0K    certs
27G     data
4.0K    generate-cert.sh
4.0K    pull-secret-bastion.txt
4.0K    pull-secret.txt
48K     sync-acm-d
[root@f16-h11-000-1029p registry]# rm -rf data/docker/
```

## Dell - Reset BMC / iDrac

In some cases the Dell idrac might need to be reset per host. This can be done with the following command:

```console
sshpass -p "password" ssh -o StrictHostKeyChecking=no user@mgmt-computer.example.com "racadm racreset"
```

Substitute the user/password/hostname to perform the reset on a desired host. Note it will take a few minutes before the BMC will become available again.

## Dell - Unable Mount Virtual Media

In some cases, the Dell iDRAC is unable to mount Virtual Media due to the Virtual Console Plug-in Type being set as eHTML5 instead of HTML5. 
To change this, navigate to Configuration -> Virtual Console -> Plug-in Type and select HTML5 instead of eHTML5.

## Scalelab - Fix boot order of machines

If a machine needs to be rebuilt in the Scale Lab and refuses to correctly rebuild, it is likely a boot order issue. Using badfish, you can correct boot order issues by performing the following:

```
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --boot-to-type foreman
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --check-boot
badfish -H mgmt-hostname -u user -p password -i config/idrac_interfaces.yml --power-cycle
```

Substitute the user/password/hostname to allow the boot order to be fixed on the host machine. Note it will take a few minutes before the machine should reboot. If you previously triggered a rebuild, the machine will likely go straight into rebuild mode afterwards. You can learn more about [badfish here](https://github.com/redhat-performance/badfish).

Note that with badfish this is a one time operation, i.e., the boot order after a rebuild/reboot will return to the original value.

Also, watch for the output of **--boot-to-type foreman**, because the correct boot order is different for SCALE vs ALIAS lab.
The values in *config/idrac_interfaces.yml* are first of all for the SCALE lab.

```console
[user@fedora badfish]$ ./src/badfish/badfish.py -H mgmt-computer.example.com -u user -p password -i config/idrac_interfaces.yml -t foreman
- INFO     - Job queue for iDRAC mgmt-computer.example.com successfully cleared.
- INFO     - PATCH command passed to update boot order.
- INFO     - POST command passed to create target config job.
- INFO     - Command passed to ForceOff server, code return is 204.
- INFO     - Polling for host state: Not Down
- POLLING: [------------------->] 100% - Host state: On
- INFO     - Command passed to On server, code return is 204.
```
## Scalelab - Upgrade RHEL

On the bastion machine:

```console
[root@f16-h11-000-1029p ~]# ./update-latest-rhel-release.sh 8.7
Changing repository from 8.2 to 8.7
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 8.7

[root@f16-h21-000-1029p ~]# dnf update -y
...
```

Reboot afterwards and start from the `create-inventory.yml` playbook.

## SuperMicro - Reset BMC / Resolving redfish connection error

In some cases, issues during a deployment can be the result of a bmc issue. To reset a Supermicro bmc use `ipmitool` with the following example:

```console
ipmitool -I lanplus -H mgmt-computer.example.com -U user -P password mc reset cold
```

The following example errors can be corrected after resetting the bmc of the machines.

```console
TASK [boot-iso : SuperMicro - Mount ISO] *****************************************************************************************
Tuesday 05 October 2021  12:20:23 -0500 (0:00:01.256)       0:01:10.117 *******
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool x.x.x.x root xxxxxxxxx wsiso mount \"http://x.x.x.x:8081\" /iso/discovery.iso\n", "delta": "0:00:00.903331", "end": "2021-10-05 12:20:24.841290", "msg": "non-zero return code", "rc": 204, "start": "2021-10-05 12:20:23.937959", "stderr": "", "stderr_lines": [], "stdout": "An ISO file already mounted. Please umount ISO first", "stdout_lines": ["An ISO file already mounted. Please umount ISO first"]}
```

```
Failed GET request to 'https://address.example.com/redfish/v1/Systems/1': 'The read operation timed out'"
```

## Supermicro - Missing Administrator IPMI privileges

Error: The node product key needs to be activated for this device

```console
TASK [boot-iso : SuperMicro - Unmount ISO] ***************************************************************************************************************************************************
Thursday 30 September 2021  15:04:14 -0400 (0:00:04.861)       0:01:51.715 ****
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool x.x.x.x root xxxxxxxxx wsiso umount\n", "delta": "0:00:00.857430", "end": "2021-09-30 14:04:15.985123", "msg": "non-zero return code", "rc": 155, "start": "2021-09-30 14:04:15.127693", "stderr": "", "stderr_lines": [], "stdout": "The node product key needs to be activated for this device", "stdout_lines": ["The node product key needs to be activated for this device"]}
```

Error: This device doesn't support WSISO commands

```console
TASK [boot-iso : SuperMicro - Unmount ISO] *************************************
Sunday 04 September 2022  15:10:25 -0500 (0:00:03.603)       0:00:21.026 ******
fatal: [jetlag-bm0]: FAILED! => {"changed": true, "cmd": "SMCIPMITool 10.220.217.126 root bybdjEBW5y wsiso umount\n", "delta": "0:00:01.319311", "end": "2022-09-04 15:10:27.754259", "msg": "non-zero return code", "rc": 153, "start": "2022-09-04 15:10:26.434948", "stderr": "", "stderr_lines": [], "stdout": "This device doesn't support WSISO commands", "stdout_lines": ["This device doesn't support WSISO commands"]}
```

The permissions of the ipmi/bmc user are likely that of operator and not administrator. Open a support case to set ipmi privilege level permissions to administrator. If you have the permissions already set correctly, try to reset bmc [here](#supermicro---reset-bmc--resolving-redfish-connection-error).

How to verify that ipmi privilege set to administrator level permissions

1. SMCIPMITool:
```console
[root@jetlag-bm0 ~]# SMCIPMITool x.x.x.x root xxxxxxxxx user list
Maximum number of Users          : 10
Count of currently enabled Users : 8
 User ID | User Name       | Privilege Level    | Enable
 ------- | -----------     | ---------------    | ------
       3 | root            | Operator           | Yes

[root@jetlag-bm0 ~]# SMCIPMITool y.y.y.y root yyyyyyyy user list
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
[root@hwprov2-bs ~]# ipmitool -I lanplus -L ADMINISTRATOR -H <IPMIADDRESS> -p 623 -U root -P <PASSWORD> power status
```

Expected result: Chassis Power is on

## Supermicro - Failure of TASK SuperMicro Set Boot

```
The property Boot is not in the list of valid properties for the resource.
```

This is caused by having an older BIOS version. The older BIOS version simply does not support the command.

When set to ignore the error, Jetlag can proceed, but you will need to manually unmount the ISO when the machines reboot the second time (as in not the reboot that happens immediately when Jetlag is run, but the one that happens after a noticeable delay). The unmount must be done as soon as the machines restart, as doing it too early can interrupt the process, and doing it after it boots into the ISO will be too late.

## Lab - Boot mode

In the ALIAS lab working with Dell machines, the boot mode of the nodes where OCP should be installed should be set to **UEFI** regardless of bm or SNO cluster types. In the SCALE lab there is no evidence of this issue, the machines are usually delivered with the **BIOS** mode set. This can be easily done with badfish:

```
badfish -H mgmt-<fqdn> -u user -p password --set-bios-attribute --attribute BootMode --value Uefi
```


Symptoms to look for: The OCP installation will successfully write the RHEL CoreOS image to the node and boot it up, where the node will be discovered by the bastion. In the virtual console of the management interface during the booting step, you can see a banner indicating *virtual media*. However, the following steps, where the OCP installation happens, will fail with a jetlag retry timeout with an error similar to:

```
Expected the host to boot from disk, but it booted the installation image - please reboot and fix boot order to boot from disk ...
```

Other things to look at:

1) Check the disk name (default in jetlag is /dev/sda, but it could be sdb, sdl, etc.), depending on how the machine's disks are configured. Verify where OCP is being installed and booted up compared to jetlag's default disk name.

2) Did the machine boot the virtual media (management interface, i.e., idrac for Dell machines)?
If the virtual media did not boot, it is most likely a *boot order* issue that is explained [here](#lab---boot-order).
Three other things to consider, however less common, are: 1) An old firmware that requires an idrac/bmc reset, 2) the DNS settings in the bmc cannot resolve the bastion, and 3) Check for subnet address collision in your local inventory file.

## Lab - Network pre-configuration

You may receive machines from the lab team with some pre-assigned IP addresses, e.g., 198.xx.
Before the OCP install and any boot order changes, ssh on the machines to nuke these IP addresses with the script *clean-interfaces.sh*.

## Lab - Ipv4 to ipv6 cluster

When moving from an ipv4 cluster installation to ipv6 (or vice-versa), instead of rebuilding machines with foreman or badfish, use *nmcli* to disable one of the IP addresses. For example, the following commands disables ipv6:

```
  nmcli c modify ens6f0 ipv6.method "disabled"
  nmcli c show ens6f0
  nmcli c show
  sysctl -p /etc/sysctl.d/ipv6.conf
  vi /etc/sysctl.conf
  sysctl -p /etc/sysctl.d/ipv6.conf
  reboot
```
