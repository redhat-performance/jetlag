# RAN workload

1. Clone the repo to the bastion machine
2. (Optional) Label nodes with labeling scripts
3. Run RAN workload

## Labels for RAN Workload

Prior to running any RAN workloads with selectors, you must create a number of labels beforehand. Scripts have been provided to make this easy.

Create 100 shared labels across the cluster

```console
./create-shared-labels.sh rwn=true 100
```

Create 100 unique labels per node per RAN workload pod (2 pods * 6 nodes * 100 labels)

```console
./create-unique-labels.sh rwn=true 1200
```

Clear all of the above created labels

```console
./clear-labels.sh rwn=true 600
```

## Running RAN workload

Pre-reqs:

* Authenticated to cluster under test
* Run on Bastion machine to apply network impairments

The RAN workload runs in several distinct phases:

1. Workload - Load cluster with Namespaces, Deployments, and Pods
2. Impairment - Apply a network impairment for a duration
3. Cleanup - Cleanup workload off cluster
4. Index - Index data collected by kube-burner over duration of test

Each phase can be disabled if intended during testing via arguements. The impairments that can be used are network latency, packet loss, and link flapping. Latency and packet loss can be combined, however link flapping must be run separate. Review the arguments to see all the options for the phases, workload, the impairments, and indexing.

Ran Workload Arguements:

```console
$ ./ran-workload.py -h
usage: ran-workload.py [-h] [--no-workload-phase] [--no-impairment-phase] [--no-cleanup-phase] [--no-index-phase] [-i ITERATIONS] [-c CPU] [-m MEM] [-s SHARED_SELECTORS] [-u UNIQUE_SELECTORS]
                       [-o OFFSET] [-n] [-D DURATION] [-I INTERFACE] [-S START_VLAN] [-E END_VLAN] [-L LATENCY] [-P PACKET_LOSS] [-F LINK_FLAP_DOWN] [-U LINK_FLAP_UP] [-d] [--dry-run] [--reset]

Run the ran workload with or without network impairments

optional arguments:
  -h, --help            show this help message and exit
  --no-workload-phase   Disables workload phase
  --no-impairment-phase
                        Disables impairment phase
  --no-cleanup-phase    Disables cleanup workload phase
  --no-index-phase      Disables index phase
  -i ITERATIONS, --iterations ITERATIONS
                        Number of RAN namespaces to create
  -c CPU, --cpu CPU     Guaranteed CPU requests/limits per pod (Cores)
  -m MEM, --mem MEM     Guaranteed Memory requests/limits per pod (GiB)
  -s SHARED_SELECTORS, --shared-selectors SHARED_SELECTORS
                        How many shared node-selectors to use
  -u UNIQUE_SELECTORS, --unique-selectors UNIQUE_SELECTORS
                        How many unique node-selectors to use
  -o OFFSET, --offset OFFSET
                        Offset for iterated unique node-selectors
  -n, --no-tolerations  Do not include tolerations on pod spec
  -D DURATION, --duration DURATION
                        Duration of impairment (Seconds)
  -I INTERFACE, --interface INTERFACE
                        Interface of vlans to impair (Ex ens1f1)
  -S START_VLAN, --start-vlan START_VLAN
                        Starting VLAN off interface (Ex 100)
  -E END_VLAN, --end-vlan END_VLAN
                        Ending VLAN off interface (Ex 105)
  -L LATENCY, --latency LATENCY
                        Number of milliseconds of latency to add to all VLANed interfaces
  -P PACKET_LOSS, --packet-loss PACKET_LOSS
                        Percentage of packet loss to add to all VLANed interfaces
  -F LINK_FLAP_DOWN, --link-flap-down LINK_FLAP_DOWN
                        Time period to flap link down (Seconds)
  -U LINK_FLAP_UP, --link-flap-up LINK_FLAP_UP
                        Time period to flap link up (Seconds)
  -d, --debug           Set log level debug
  --dry-run             Echos commands instead of executing them
  --reset               Attempts to undo all network impairments
```
