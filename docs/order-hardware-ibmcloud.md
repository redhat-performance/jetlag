# Order hardware on IBMcloud guide

## Prerequisites

Ensure you have access to IBMcloud (https://cloud.ibm.com). You will need to contact the lab manager to get an account created.

Currently tested hardware vendors in Jetlag are 'Supermicro' and 'Lenovo'. Unfortunately, you will not get to know which vendor the servers are from until your devices are ready.


## Ordering Hardware

Login to your IBMcloud account

Browse to Catalog and filter 'Compute'. Select Bare Metal Servers from the list of filtered products

You can select the location/datacenter and the Server profile based on cost estimates

For baremetal deployment, you will need:

* One server to be provisioned as your bastion machine
* Three additional servers to serve as control-plane nodes
* At least two more servers to serve as worker nodes in your openshift cluster

The following guides can also assist you with procurement of devices:

https://cloud.ibm.com/docs/bare-metal?topic=bare-metal-getting-started

https://cloud.ibm.com/docs/bare-metal?topic=bare-metal-about-bm

Points to keep in mind while ordering hardware:

* Ensure that you order either CentOS or RHEL machines with a new enough version (8.6) otherwise podman will not have host networking functionality
* Add your SSH keys while ordering. Generate a new key pair for ibmcloud as a best practice.
* Select an SSD disk
* 32 GB RAM at minimum
* Port speed of 10 Gbps at minimum
* The bastion machine should have a public accessible ip and will NAT traffic for the cluster to the public network. Other machines can have a public ip address but it is not currently in use with this deployment method.

You might not receive an immediate notification on the order you just placed.
If there are significant delays, IBMcloud will open up a ticket on your behalf to notify about the readiness status of your servers.

Once you are notified of the servers being ready, login to IBMcloud and navigate to 'Classic Infrastructure' to view your devices.


## Post Hardware acquisition

**IBMcloud VPN access:**

To manage your servers remotely and securely over the IBM Cloud private network, you need to connect to IBMcloud VPN.

To get started, refer to https://cloud.ibm.com/docs/iaas-vpn?topic=iaas-vpn-getting-started

**IBMcloud Shell:**

To get started with IBMcloud shell, refer to https://cloud.ibm.com/docs/cloud-shell?topic=cloud-shell-getting-started

Once you have successfully logged into the IBMcloud Shell, you should be able to list  your devices using the following command:

```console
[user@<local>]$ ibmcloud sl hardware list
```

Sample output:

```console
[user@<local>]$ ibmcloud sl hardware list
id        hostname     domain                    public_ip        private_ip    datacenter   status
960237    jetlag-bm0   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
1165601   jetlag-bm1   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
1112925   jetlag-bm2   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
1163781   jetlag-bm3   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
1165519   jetlag-bm4   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
1117051   jetlag-bm5   performance-scale.cloud   X.X.X.X          X.X.X.X       dal10        ACTIVE
```

**IBMcloud Support Cases:**

To open a support case with IBMcloud, access the link below:
https://cloud.ibm.com/unifiedsupport/supportcenter
