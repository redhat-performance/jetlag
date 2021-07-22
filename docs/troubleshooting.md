# Troubleshooting jetlag

_**Table of Contents**_

<!-- TOC -->
- [Accessing services off the bastion](#accessing-services-off-the-bastion)
- [Cleaning all pods/containers off the bastion machines](#cleaning-all-podscontainers-off-the-bastion-machines)
- [Upgrade RHEL to 8.4 in Scalelab](#upgrade-rhel-to-84-in-scalelab)
- [Resetting SuperMicro BMC / Resolving redfish connection error](#resetting-supermicro-bmc-resolving-redfish-connection-error)
- [Resetting Dell iDrac](#resetting-dell-idrac)
- [Failure of TASK SuperMicro Set Boot](#failure-of-task-supermicro-set-boot)
- [Fix boot order of machines in Scale Lab](#fix-boot-order-of-machines-in-scale-lab)
- [Clean all container images from disconnected registry on bastion](#clean-all-container-images-from-disconnected-registry-on-bastion)
<!-- /TOC -->

## Accessing services off the bastion

Several services are run on the bastion in order to automate the tasks that jetlag performs. You can access them via the following ports:

* On-prem assisted-installer GUI - 8080
* On-prem assisted-installer API - 8090
* HTTP server - 8081
* Container Registry (When disconnected) - 5000
* HAProxy (When disconnected) - 6443, 443, 80
* Dnsmasq - 53

Examples, change the FQDN to your bastion machine and open in your browser
```
AI Gui - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8080/
AI API - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8090/
HTTP Server - http://f99-h11-000-1029p.rdu2.scalelab.redhat.com:8081/
```

Example accessing the disconnected registry and listing repositories:
```console
[root@f99-h11-000-1029p akrzos]# curl -u registry:registry -k https://f99-h11-000-1029p.rdu2.scalelab.redhat.com:5000/v2/_catalog?n=100 | jq                                                 
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   532  100   532    0     0    104      0  0:00:05  0:00:05 --:--:--   120
{
  "repositories": [
    "ocp4/openshift4",
    "ocpmetal/assisted-installer",
    "ocpmetal/assisted-installer-agent",
    "ocpmetal/assisted-installer-controller",
    "ocpmetal/assisted-service",
    "ocpmetal/ocp-metal-ui",
    "ocpmetal/postgresql-12-centos7",
    "olm-mirror/olm-mirror-redhat-operator-index",
    "olm-mirror/openshift4-ose-local-storage-diskmaker",
    "olm-mirror/openshift4-ose-local-storage-operator",
    "olm-mirror/openshift4-ose-local-storage-operator-bundle",
    "olm-mirror/openshift4-ose-local-storage-static-provisioner",
    "olm-mirror/redhat-operator-index"
  ]
}
```

## Cleaning all pods/containers off the bastion machines

In the event you believe your running containers on the bastion have incorrect data or you are deploying a new OCP version and need to remove the containers in order to rerun the `setup-bastion.yml` playbook.

Clean **all** containers (on your bastion machine):

```console
podman ps | awk '{print $1}' | xargs -I % podman stop %; podman ps -a | awk '{print $1}' | xargs -I % podman rm %; podman pod ps | awk '{print $1}' | xargs -I % podman pod rm %
```

When replacing the ocp version, just remove the assisted-installer pod and container, then rerun the `setup-bastion.yml` playbook.

## Upgrade RHEL to 8.4 in Scalelab

On the bastion machine:

```console
[root@f16-h11-000-1029p ~]# ./update-latest-rhel-release.sh 8.4
Changing repository from 8.2 to 8.4
Cleaning dnf repo cache..

-------------------------
Run dnf update to upgrade to RHEL 8.4

[root@f16-h21-000-1029p ~]# dnf update -y
...
```

Reboot afterwards and start from the `create-inventory.yml` playbook.

## Resetting SuperMicro BMC / Resolving redfish connection error

```
Failed GET request to 'https://address.example.com/redfish/v1/Systems/1': 'The read operation timed out'"
```

In that case, if it normally works, it can be helpful to reset the baseboard management controller with:
```console
ipmitool -I lanplus -H mgmt-computer.example.com -U user -P password mc reset cold
```

If that fails, verify that the server supports the redfish API.

## Resetting Dell iDrac

In some cases the dell idrac might need to be reset per host. This can be done with the following command:

```console
sshpass -p "password" ssh -o StrictHostKeyChecking=no user@mgmt-computer.example.com "racadm racreset"
```

Substitute the user/password/hostname to perform the reset on a desired host. Note it will take a few minutes before the BMC will become available again.

## Failure of TASK SuperMicro Set Boot

```
The property Boot is not in the list of valid properties for the resource.
```

This is caused by having an older BIOS version. The older BIOS version simply does not support the command.

When set to ignore the error, JetLag can proceed, but you will need to manually unmount the ISO when the machines reboot the second time (as in not the reboot that happens immediately when Jetlag is run, but the one that happens after a noticeable delay). The unmount must be done as soon as the machines restart, as doing it too early can interrupt the process, and doing it after it boots into the ISO will be too late.

## Fix boot order of machines in Scale Lab

If a machine needs to be rebuilt in the Scale Lab and refuses to correctly rebuild, it is likely a boot order issue. Using badfish, you can correct boot order issues by performing the following:

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

Substitute the user/password/hostname to allow the boot order to be fixed on the host machine. Note it will take a few minutes before the machine should reboot. If you previously triggered a rebuild, the machine will likely go straight into rebuild mode afterwards. You can learn more about [badfish here](https://github.com/redhat-performance/badfish).

## Clean all container images from disconnected registry on bastion

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
-rw-r--r--. 1 root root 3.0K Jul 20 20:31 pull-secret-disconnected.txt
-rw-r--r--. 1 root root 2.9K Jul 20 02:27 pull-secret.txt
drwxr-xr-x. 2 root root  191 Jul 21 12:26 sync-acm-d
[root@f16-h11-000-1029p registry]# du -sh *
4.0K    auth
8.0K    certs
27G     data
4.0K    generate-cert.sh
4.0K    pull-secret-disconnected.txt
4.0K    pull-secret.txt
48K     sync-acm-d
[root@f16-h11-000-1029p registry]# rm -rf data/docker/
```
