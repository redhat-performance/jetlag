# jetlag workload

The jetlag workload is designed to stress test node density and remote worker node clusters.

1. Clone the repo to the bastion machine
2. Install python requirements - `pip3 install -r requirements.txt`
3. (Optional) Label nodes with `labeler.py`
4. Run `jetlag-workload.py`

## Labels for jetlag workload

Prior to running jetlag workloads with selectors, you must create a number of labels beforehand.

Create 100 shared labels across the remote worker nodes:

```console
./labeler.py -c 100 -s
```

Create 100 unique labels per node per jetlag workload pod:

```console
./labeler.py -c 100 -u
```

Clear all 100 shared and unique labels off the remote worker nodes:

```console
./labeler.py -c 100 -su --clear
```

## Running jetlag workload

Pre-reqs:

* Authenticated to cluster under test

Additional Pre-req for Remote Worker Node Test Environments:

* Run on Bastion machine to apply network impairments

The jetlag workload runs in several distinct phases:

1. Workload - Load cluster with Namespaces, Deployments, Pods, and Services
2. Measurement - Keeps cluster loaded and allows network impairments for a duration
3. Cleanup - Cleanup workload off cluster
4. Index - Index data collected by kube-burner over duration of test

Each phase can be disabled if intended during testing via arguments. The impairments that can be used are network bandwidth limits, latency, packet loss and link flapping. Bandwidth, latency, and packet loss can only be combined with link flapping if the firewall option is set. Review the arguments to see all the options for each phase.

jetlag workload arguments:

```console
$ ./jetlag-workload.py -h
usage: jetlag-workload.py [-h] [--no-workload-phase] [--no-measurement-phase] [--no-cleanup-phase] [--no-index-phase] [-n NAMESPACES] [-d DEPLOYMENTS] [-l] [-p PODS] [-c CONTAINERS]
                          [-i CONTAINER_IMAGE] [--container-port CONTAINER_PORT] [-e [CONTAINER_ENV ...]] [-m CONFIGMAPS] [--secrets SECRETS] [--cpu-requests CPU_REQUESTS]
                          [--memory-requests MEMORY_REQUESTS] [--cpu-limits CPU_LIMITS] [--memory-limits MEMORY_LIMITS] [--startup-probe STARTUP_PROBE] [--liveness-probe LIVENESS_PROBE]
                          [--readiness-probe READINESS_PROBE] [--startup-probe-endpoint STARTUP_PROBE_ENDPOINT] [--liveness-probe-endpoint LIVENESS_PROBE_ENDPOINT]
                          [--readiness-probe-endpoint READINESS_PROBE_ENDPOINT] [--no-probes] [--default-selector DEFAULT_SELECTOR] [-s SHARED_SELECTORS] [-u UNIQUE_SELECTORS] [-o OFFSET]
                          [--no-tolerations] [-D DURATION] [-I INTERFACE] [-S START_VLAN] [-E END_VLAN] [-L LATENCY] [-P PACKET_LOSS] [-B BANDWIDTH_LIMIT] [-F LINK_FLAP_DOWN]
                          [-U LINK_FLAP_UP] [-T] [-N LINK_FLAP_NETWORK] [--index-server INDEX_SERVER] [--default-index DEFAULT_INDEX] [--measurements-index MEASUREMENTS_INDEX]
                          [--prometheus-url PROMETHEUS_URL] [--prometheus-token PROMETHEUS_TOKEN] [--debug] [--dry-run] [--reset]

Run the jetlag workload

optional arguments:
  -h, --help            show this help message and exit
  --no-workload-phase   Disables workload phase (default: False)
  --no-measurement-phase
                        Disables measurement phase (default: False)
  --no-cleanup-phase    Disables cleanup workload phase (default: False)
  --no-index-phase      Disables index phase (default: False)
  -n NAMESPACES, --namespaces NAMESPACES
                        Number of namespaces to create (default: 1)
  -d DEPLOYMENTS, --deployments DEPLOYMENTS
                        Number of deployments per namespace to create (default: 1)
  -l, --service         Include service per deployment (default: False)
  -p PODS, --pods PODS  Number of pod replicas per deployment to create (default: 1)
  -c CONTAINERS, --containers CONTAINERS
                        Number of containers per pod replica to create (default: 1)
  -i CONTAINER_IMAGE, --container-image CONTAINER_IMAGE
                        The container image to use (default: quay.io/redhat-performance/test-gohttp-probe:latest)
  --container-port CONTAINER_PORT
                        The starting container port to expose (PORT Env Var) (default: 8000)
  -e [CONTAINER_ENV ...], --container-env [CONTAINER_ENV ...]
                        The container environment variables (default: ['LISTEN_DELAY_SECONDS=20', 'LIVENESS_DELAY_SECONDS=10READINESS_DELAY_SECONDS=30', 'RESPONSE_DELAY_MILLISECONDS=50',
                        'LIVENESS_SUCCESS_MAX=60', 'READINESS_SUCCESS_MAX=30'])
  -m CONFIGMAPS, --configmaps CONFIGMAPS
                        Number of configmaps per container (default: 0)
  --secrets SECRETS     Number of secrets per container (default: 0)
  --cpu-requests CPU_REQUESTS
                        CPU requests per container (millicores) (default: 0)
  --memory-requests MEMORY_REQUESTS
                        Memory requests per container (MiB) (default: 0)
  --cpu-limits CPU_LIMITS
                        CPU limits per container (millicores) (default: 0)
  --memory-limits MEMORY_LIMITS
                        Memory limits per container (MiB) (default: 0)
  --startup-probe STARTUP_PROBE
                        Container startupProbe configuration (default: http,0,10,1,12)
  --liveness-probe LIVENESS_PROBE
                        Container livenessProbe configuration (default: http,0,10,1,3)
  --readiness-probe READINESS_PROBE
                        Container readinessProbe configuration (default: http,0,10,1,3,1)
  --startup-probe-endpoint STARTUP_PROBE_ENDPOINT
                        startupProbe endpoint (default: /livez)
  --liveness-probe-endpoint LIVENESS_PROBE_ENDPOINT
                        livenessProbe endpoint (default: /livez)
  --readiness-probe-endpoint READINESS_PROBE_ENDPOINT
                        readinessProbe endpoint (default: /readyz)
  --no-probes           Disable all probes (default: False)
  --default-selector DEFAULT_SELECTOR
                        Default node-selector (default: jetlag: 'true')
  -s SHARED_SELECTORS, --shared-selectors SHARED_SELECTORS
                        How many shared node-selectors to use (default: 0)
  -u UNIQUE_SELECTORS, --unique-selectors UNIQUE_SELECTORS
                        How many unique node-selectors to use (default: 0)
  -o OFFSET, --offset OFFSET
                        Offset for iterated unique node-selectors (default: 0)
  --no-tolerations      Do not include RWN tolerations on pod spec (default: False)
  -D DURATION, --duration DURATION
                        Duration of measurent/impairment phase (Seconds) (default: 30)
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
  -B BANDWIDTH_LIMIT, --bandwidth-limit BANDWIDTH_LIMIT
                        Bandwidth limit to apply to all VLANed interfaces (kilobits). 0 for no limit. (default: 0)
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
                        Default index (default: jetlag-default-test)
  --measurements-index MEASUREMENTS_INDEX
                        Measurements index (default: jetlag-measurements-test)
  --prometheus-url PROMETHEUS_URL
                        Cluster prometheus URL (default: )
  --prometheus-token PROMETHEUS_TOKEN
                        Token to access prometheus (default: )
  --debug               Set log level debug (default: False)
  --dry-run             Echos commands instead of executing them (default: False)
  --reset               Attempts to undo all network impairments (default: False)
```

## jetlag workload object hierarchy

The jetlag workload creates objects in a hierarchy:

* Namespaces
  * Deployments per namespace
    * 1 Service per deployment (if enabled)
    * 1 Route per deployment (if enabled)
    * Pods per deployment
      * Containers per pod

Thus if you want to create 100 pods you can do so in more than one hierarchy:

```console
$ ./jetlag-workload.py -n 1 -d 50 -p 2
```

The above command creates 1 namespace with 50 deployments, each with 2 pod replicas resulting in 100 pods.

As another example:

```console
$ ./jetlag-workload.py -n 10 -d 10 -p 1
```

The above command creates 10 namespaces with 10 deployments, each with 1 pod replica resulting in 100 pods.

To create a service per deployment which will expose and load balance traffic to pod replicas, use the `-l` argument. This is used when you have a readiness probe so that kubernetes must handle endpoints if readiness flaps or fails.

## jetlag workload container resource configuration

The jetlag workload allows you to set cpu and memory requests/limits at the container level. The following arguments set the cpu and memory resources:

* `--cpu-requests CPU_REQUESTS`
* `--memory-requests MEMORY_REQUESTS`
* `--cpu-limits CPU_LIMITS`
* `--memory-limits MEMORY_LIMITS`

CPU requests and limits is in millicores, thus `1000` equals 1 cpu core. Memory requests and limits is in MiB, thus `1024` equals 1 GiB. Keep in mind total cluster capacity when setting requests and limits and whether the expected workload will be able to be scheduled into the cluster under test. Depending upon the argument values here you will affect whether or not the pods QoS is either Best-Effort, Burstable, or Guaranteed.

## jetlag workload container image configuration

The jetlag workload allows setting a custom image with the containers it deploys. Use the `-i` option to change the container image. The default container image is `quay.io/redhat-performance/test-gohttp-probe:latest`. The `test-gohttp-probe` container image exposes a `livez` and `readyz` endpoint so you can easily test probe configuration in conjunction with various object hierarchies.

An example of a container image that works with all probes disabled is the pause pod.

```console
$ ./jetlag-workload.py -i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes
```

## jetlag workload container probe configuration

If you use the default container image `quay.io/redhat-performance/test-gohttp-probe:latest`, you can use startup, liveness, and readiness probes. The defaults work but you might want to configure the various probe options or a different image might use different endpoints. The probe configuration arguments are:

* `--startup-probe STARTUP_PROBE`
* `--liveness-probe LIVENESS_PROBE`
* `--readiness-probe READINESS_PROBE`
* `--startup-probe-endpoint STARTUP_PROBE_ENDPOINT`
* `--liveness-probe-endpoint LIVENESS_PROBE_ENDPOINT`
* `--readiness-probe-endpoint READINESS_PROBE_ENDPOINT`

Each probe takes a comma separated string for configuration that consists of the probe type followed by 4 or 5 integer values. The endpoint arguments simply take a string of what endpoint is expected for which probe for the specific application.

```console
$ ./jetlag-workload.py --startup-probe http,0,10,1,12 --liveness-probe http,0,10,1,3 --readiness-probe http,0,10,1,3,1
```

The first option in the comma separated string can be either `http`, `tcp`, or `off`. The remaining options are all integers and configure these probe options in the order shown:

```yaml
initialDelaySeconds: 0
periodSeconds: 10
timeoutSeconds: 1
failureThreshold: 12
successThreshold: 1
```

See this [kubernetes documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/#configure-probes) that describes each configuration item. Note that startup and liveness probes must configure `successThreshold` to value `1`. Since it is the last argument, it can be left off so the default is consumed for both those probes.

## jetlag workload container environment configuration

The jetlag workload can configure custom environmental variables with passed in arguments. The `-e` argument is used to define the custom environment variables.

```console
./jetlag-workload.py -e LISTEN_DELAY_SECONDS=20 LIVENESS_DELAY_SECONDS=10 READINESS_DELAY_SECONDS=30 RESPONSE_DELAY_MILLISECONDS=50 LIVENESS_SUCCESS_MAX=60 READINESS_SUCCESS_MAX=30
```

This results in the following environment variable configuration for each container jetlag workload creates:

```yaml
env:
- name: PORT
  value: "8001"
- name: LISTEN_DELAY_SECONDS
  value: "60"
- name: LIVENESS_DELAY_SECONDS
  value: "10"
- name: READINESS_DELAY_SECONDS
  value: "30"
- name: RESPONSE_DELAY_MILLISECONDS
  value: "50"
- name: LIVENESS_SUCCESS_MAX
  value: "60"
- name: READINESS_SUCCESS_MAX
  value: "30"
```

The `PORT` environment variable is provided automatically and incremented based on the number of containers specified (`-c` argument). Combined with container image `quay.io/redhat-performance/test-gohttp-probe`, these environment vars configure the behavior of the app to the kubernetes probes. The example provided is actually the default.
