# RWN workload

1. Clone the repo to the bastion machine
2. (Optional) Label nodes with labeling scripts
3. Run RWN workload

## Labels for RWN Workload

Prior to running any RWN workloads with selectors, you must create a number of labels beforehand. Scripts have been provided to make this easy.

Create 100 shared labels across the cluster

```console
./create-shared-labels.sh rwn=true 100
```

Create 100 unique labels per node per RWN workload pod (2 pods * 6 nodes * 100 labels)

```console
./create-unique-labels.sh rwn=true 1200
```

Clear all of the above created labels

```console
./clear-labels.sh rwn=true 600
```

## Running RWN workload

Pre-reqs:

* Authenticated to cluster under test
* Run on Bastion machine to apply network impairments

The RWN workload runs in several distinct phases:

1. Workload - Load cluster with Namespaces, Deployments, and Pods
2. Impairment - Apply a network impairment for a duration
3. Cleanup - Cleanup workload off cluster
4. Index - Index data collected by kube-burner over duration of test

Each phase can be disabled if intended during testing via arguements. The impairments that can be used are network latency, packet loss, and link flapping. Latency and packet loss can be combined, however link flapping must be run separate. Review the arguments to see all the options for the phases, workload, the impairments, and indexing.

RWN Workload Arguements:

```console
$ ./rwn-workload.py -h
usage: rwn-workload.py [-h] [--no-workload-phase] [--no-impairment-phase] [--no-cleanup-phase] [--no-index-phase] [-i ITERATIONS] [-c CPU] [-m MEM] [-s SHARED_SELECTORS]
                       [-u UNIQUE_SELECTORS] [-o OFFSET] [-n] [-D DURATION] [-I INTERFACE] [-S START_VLAN] [-E END_VLAN] [-L LATENCY] [-P PACKET_LOSS] [-F LINK_FLAP_DOWN] [-U LINK_FLAP_UP]
                       [-T] [-N LINK_FLAP_NETWORK] [--index-server INDEX_SERVER] [--default-index DEFAULT_INDEX] [--measurements-index MEASUREMENTS_INDEX] [--prometheus-url PROMETHEUS_URL]
                       [--prometheus-token PROMETHEUS_TOKEN] [-d] [--dry-run] [--reset]

Run the rwn workload with or without network impairments

optional arguments:
  -h, --help            show this help message and exit
  --no-workload-phase   Disables workload phase (default: False)
  --no-impairment-phase
                        Disables impairment phase (default: False)
  --no-cleanup-phase    Disables cleanup workload phase (default: False)
  --no-index-phase      Disables index phase (default: False)
  -i ITERATIONS, --iterations ITERATIONS
                        Number of RWN namespaces to create (default: 12)
  -c CPU, --cpu CPU     Guaranteed CPU requests/limits per pod (Cores or millicores) (default: 29)
  -m MEM, --mem MEM     Guaranteed Memory requests/limits per pod (GiB) (default: 120)
  -s SHARED_SELECTORS, --shared-selectors SHARED_SELECTORS
                        How many shared node-selectors to use (default: 100)
  -u UNIQUE_SELECTORS, --unique-selectors UNIQUE_SELECTORS
                        How many unique node-selectors to use (default: 100)
  -o OFFSET, --offset OFFSET
                        Offset for iterated unique node-selectors (default: 6)
  -n, --no-tolerations  Do not include tolerations on pod spec (default: False)
  -D DURATION, --duration DURATION
                        Duration of impairment (Seconds) (default: 30)
  -I INTERFACE, --interface INTERFACE
                        Interface of vlans to impair (default: ens1f1)
  -S START_VLAN, --start-vlan START_VLAN
                        Starting VLAN off interface (default: 100)
  -E END_VLAN, --end-vlan END_VLAN
                        Ending VLAN off interface (default: 105)
  -L LATENCY, --latency LATENCY
                        Amount of latency to add to all VLANed interfaces (milliseconds) (default: 0)
  -P PACKET_LOSS, --packet-loss PACKET_LOSS
                        Percentage of packet loss to add to all VLANed interfaces (default: 0)
  -F LINK_FLAP_DOWN, --link-flap-down LINK_FLAP_DOWN
                        Time period to flap link down (Seconds) (default: 0)
  -U LINK_FLAP_UP, --link-flap-up LINK_FLAP_UP
                        Time period to flap link up (Seconds) (default: 0)
  -T, --link-flap-firewall
                        Flaps links via iptables instead of ip link set (default: False)
  -N LINK_FLAP_NETWORK, --link-flap-network LINK_FLAP_NETWORK
                        Network to block for iptables link flapping (default: 198.18.10.0/24)
  --index-server INDEX_SERVER
                        ElasticSearch server (Ex https://user:password@example.org:9200) (default: )
  --default-index DEFAULT_INDEX
                        Default index (default: rwn-default-test)
  --measurements-index MEASUREMENTS_INDEX
                        Measurements index (default: rwn-measurements-test)
  --prometheus-url PROMETHEUS_URL
                        Cluster prometheus URL (default: )
  --prometheus-token PROMETHEUS_TOKEN
                        Token to access prometheus (default: )
  -d, --debug           Set log level debug (default: False)
  --dry-run             Echos commands instead of executing them (default: False)
  --reset               Attempts to undo all network impairments (default: False)
```
