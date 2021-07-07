# Troubleshooting jetlag

## Accessing services off the bastion

Several services are run on the bastion in order to automate the tasks that jetlag performs. You can access them via the following ports:

* On-prem assisted-installer GUI - 8080
* On-prem assisted-installer API - 8090
* HTTP server - 8081
* Disconnected Registry (When set) - 5000
* 53 - Dnsmasq

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

## Upgrade RHEL to 8.4 in Scalelab to run ipv6/disconnected

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
