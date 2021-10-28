# Order hardware on IBMcloud guide

## Prerequisites

Ensure you have access to IBMcloud (https://cloud.ibm.com). Contact the system admin (Noushin Atashband) to get an account created.
Currenlty supported hardware vendors in Jetlag are 'Supermicro' and 'Lenovo'. Unfortunately. you will not get to know which vendor the servers are from until your devices are ready.


## Ordering Hardware

Login to your IBMcloud account

Browse to Catalog and filter 'Compute'. Select Bare Metal Servers from the list of filtered products

You can select the location/datacenter and the Server profile based on cost estimates

For baremetal deployment, you will need:
1. One server to be provisioned as your bastion machine,
2. Three additional servers to serve as control-plane nodes, and 
3. At least two more servers to serve as worker nodes in your openshift cluster

The following guides can also assist you with procurement of devices:
https://cloud.ibm.com/docs/bare-metal?topic=bare-metal-getting-started
https://cloud.ibm.com/docs/bare-metal?topic=bare-metal-about-bm

Points to keep in mind while ordering hardware:
1. Ensure that you order either CentOS or RHEL machines with a new enough version (8.4) otherwise podman will not have host networking functionality
2. Add your SSH keys while ordering. Generate a new key pair for ibmcloud just so you don't expose you generic ssh keys to the internet
3. Select an SSD disk
4. 64 GB RAM
5. Port speed of 10 Gbps at minimum
6. The bastion machine should have a public accessible ip and will NAT traffic for the cluster to the public network. Other machines can have a public ip address but it is not currently in use with this deployment method.

You might not receive an immediate notification on the order you just placed. 
If there are significant delays, IBMcloud will open up a support ticket on your behalf to notify about the readiness status of your servers.

Once you are notified of the servers being ready, login to IBMcloud and select 'Classic Infrastructure' to view your devices.


## Post Hardware acquisition

IBMcloud VPN access:
To manage your servers remotely and securely over the IBM Cloud private network, you need to connect to IBMcloud VPN. To get started, refer to https://cloud.ibm.com/docs/iaas-vpn?topic=iaas-vpn-getting-started

IBMcloud Shell:
To get started with IBMcloud shell, refer to https://cloud.ibm.com/docs/cloud-shell?topic=cloud-shell-getting-started
Once you have access to IBMcloud CLI, view your devices using the following command:
ibmcloud sl hardware list

IBMcloud Support Cases:
To open a support case with IBMcloud, access the link below:
https://cloud.ibm.com/unifiedsupport/supportcenter
