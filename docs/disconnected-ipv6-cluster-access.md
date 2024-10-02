# Accessing a disconnected/ipv6 cluster deployed by Jetlag

Jetlag includes the installation of a HAProxy instance on the bastion machine with ipv6/disconnected environment setup.  The HAProxy instance allows you to proxy traffic over ports 6443, 443, and 80 into the deployed disconnected cluster. Port 6443 is for access to the cluster api (Ex. oc cli commands), and ports 443/80 are for ingress routes such as console or grafana. This effectively allows you to reach the disconnected cluster from your local laptop. In order to do so you will need to edit your laptop's `/etc/hosts` and insert the routes that map to your cluster. While running the `setup-bastion.yml` playbook, an example copy of the hosts file is dumped into `bastion_cluster_config_dir` which is typically `/root/mno` for multi node cluster type.

Example:

```console
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
$BASTION_IP dittybopper-dittybopper.apps.mno.example.com
```

`$BASTION_IP` should be the ip address that you can access the bastion from your laptop. If you create new routes you can always append them to your `/etc/hosts` file in order to reach any newly created routes.
