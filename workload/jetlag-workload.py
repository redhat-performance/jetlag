#!/usr/bin/env python3
#  Copyright 2021 Red Hat
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

import argparse
from jinja2 import Template
import json
import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


workload_create = """---
global:
  writeToFile: false
  measurements:
  - name: podLatency
    esIndex: {{ measurements_index }}

  indexerConfig:
    enabled: {{ indexing }}
    esServers: [{{ index_server}}]
    insecureSkipVerify: true
    defaultIndex: {{ default_index }}
    type: elastic

jobs:
  - name: jetlag
    jobType: create
    jobIterations: {{ namespaces }}
    qps: 20
    burst: 40
    namespacedIterations: true
    cleanup: true
    namespace: jetlag
    podWait: false
    waitWhenFinished: true
    verifyObjects: true
    errorOnVerify: false
    jobIterationDelay: 0s
    jobPause: 0s
    objects:
    - objectTemplate: workload-deployment-selector.yml
      replicas: {{ deployments }}
      inputVars:
        pod_replicas: {{ pod_replicas }}
        containers: {{ containers }}
        image: {{ container_image }}
        set_requests_cpu: {{ cpu_requests > 0 }}
        set_requests_memory: {{ memory_requests > 0 }}
        set_limits_cpu: {{ cpu_limits > 0 }}
        set_limits_memory: {{ memory_limits > 0 }}
        resources:
          requests:
            cpu: {{ cpu_requests }}m
            memory: {{ memory_requests }}Mi
          limits:
            cpu: {{ cpu_limits }}m
            memory: {{ memory_limits }}Mi
        container_env_args: {{ container_env_args }}
        enable_startup_probe: {{ startup_probe_args | length > 0 }}
        enable_liveness_probe: {{ liveness_probe_args | length > 0 }}
        enable_readiness_probe: {{ readiness_probe_args | length > 0 }}
        startup_probe_args: {{ startup_probe_args }}
        liveness_probe_args: {{ liveness_probe_args }}
        readiness_probe_args: {{ readiness_probe_args }}
        default_selector: "{{ default_selector }}"
        shared_selectors: {{ shared_selectors }}
        unique_selectors: {{ unique_selectors }}
        unique_selector_offset: {{ offset }}
        tolerations: {{ tolerations }}
    {% if service %}
    - objectTemplate: workload-service.yml
      replicas: {{ deployments }}
      inputVars:
        ports: {{ containers }}
    {% endif %}
"""

workload_delete = """---
global:
  writeToFile: false
  measurements:
  - name: podLatency
    esIndex: {{ measurements_index }}

  indexerConfig:
    enabled: {{ indexing }}
    esServers: [{{ index_server}}]
    insecureSkipVerify: true
    defaultIndex: {{ default_index }}
    type: elastic

jobs:
- name: cleanup-jetlag
  jobType: delete
  waitForDeletion: true
  qps: 10
  burst: 20
  objects:

  - kind: Service
    labelSelector: {kube-burner-job: jetlag}
    apiVersion: v1

  - kind: Deployment
    labelSelector: {kube-burner-job: jetlag}
    apiVersion: apps/v1

  - kind: Namespace
    labelSelector: {kube-burner-job: jetlag}
    apiVersion: v1
"""

workload_index = """---
global:
  writeToFile: false
  measurements:
  - name: podLatency
    esIndex: {{ measurements_index }}

  indexerConfig:
    enabled: true
    esServers: [{{ index_server}}]
    insecureSkipVerify: true
    defaultIndex: {{ default_index }}
    type: elastic
"""

workload_deployment = """---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jetlag-{{ .Iteration }}-{{ .Replica }}-{{.JobName }}
spec:
  replicas: {{ .pod_replicas }}
  selector:
    matchLabels:
      app: jetlag-{{ .Iteration }}-{{ .Replica }}
  strategy:
    resources: {}
  template:
    metadata:
      labels:
        app: jetlag-{{ .Iteration }}-{{ .Replica }}
    spec:
      containers:
      {{ $data := . }}
      {{ range $index, $element := sequence 1 .containers }}
      - name: jetlag-container-{{ $element }}
        image: {{ $data.image }}
        ports:
        - containerPort: {{ add 8000 $element }}
          protocol: TCP
        resources:
          requests:
            {{ if $data.set_requests_cpu }}
            cpu: {{ $data.resources.requests.cpu }}
            {{ end }}
            {{if $data.set_requests_memory }}
            memory: {{ $data.resources.requests.memory }}
            {{ end }}
          limits:
            {{ if $data.set_limits_cpu }}
            cpu: {{ $data.resources.limits.cpu }}
            {{ end }}
            {{ if $data.set_limits_memory }}
            memory: {{ $data.resources.limits.memory }}
            {{ end }}
        env:
        - name: PORT
          value: "{{ add 8000 $element }}"
        {{ range $data.container_env_args }}
        - name: "{{ .name }}"
          value: "{{ .value }}"
        {{ end }}
        {{ if $data.enable_startup_probe }}
        startupProbe:
          {{ range $data.startup_probe_args }}
          {{ . }}
          {{ end }}
            port: {{ add 8000 $element }}
          {{ end }}
        {{ if $data.enable_liveness_probe }}
        livenessProbe:
          {{ range $data.liveness_probe_args }}
          {{ . }}
          {{ end }}
            port: {{ add 8000 $element }}
        {{ end }}
        {{ if $data.enable_readiness_probe }}
        readinessProbe:
          {{ range $data.readiness_probe_args }}
          {{ . }}
          {{ end }}
            port: {{ add 8000 $element }}
        {{ end }}
      {{ end }}
      nodeSelector:
        {{ .default_selector }}
        {{ range $index, $element := sequence 1 .shared_selectors }}
        jetlags-{{ $element }}: "true"
        {{ end }}
        {{ $data := . }}
        {{ range $index, $element := sequence 1 $data.unique_selectors }}
        {{ $first := multiply $data.unique_selector_offset $index }}
        jetlagu-{{ add $first $data.Iteration }}: "true"
        {{ end }}
      {{ if .tolerations }}
      tolerations:
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
      - key: "node.kubernetes.io/unschedulable"
        operator: "Exists"
        effect: "NoExecute"
      {{ end }}
"""

workload_service = """---
apiVersion: v1
kind: Service
metadata:
  name: jetlag-{{ .Iteration }}-{{ .Replica }}-{{.JobName }}
spec:
  selector:
    app: jetlag-{{ .Iteration }}-{{ .Replica }}
  ports:
    {{ range $index, $element := sequence 1 .ports }}
    - protocol: TCP
      name: port-{{ add 8000 $element }}
      port: {{ add 80 $element }}
      targetPort: {{ add 8000 $element }}
    {{ end }}
"""

logging.basicConfig(level=logging.INFO, format='%(asctime)s : %(levelname)s : %(message)s')
logger = logging.getLogger('Jetlag-Workload')
logging.Formatter.converter = time.gmtime


def command(cmd, dry_run, cmd_directory="", mask_output=False, mask_arg=0, no_log=False):
  if cmd_directory != "":
    logger.debug("Command Directory: {}".format(cmd_directory))
    working_directory = os.getcwd()
    os.chdir(cmd_directory)
  if dry_run:
    cmd.insert(0, "echo")
  if mask_arg == 0:
    logger.info("Command: {}".format(" ".join(cmd)))
  else:
    logger.info("Command: {} {} {}".format(" ".join(cmd[:mask_arg - 1]), "**(Masked)**", " ".join(cmd[mask_arg:])))
  process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

  output = ""
  while True:
    output_line = process.stdout.readline()
    if output_line.strip() != "":
      if not no_log:
        if not mask_output:
          logger.info("Output : {}".format(output_line.strip()))
        else:
          logger.info("Output : **(Masked)**")
      if output == "":
        output = output_line.strip()
      else:
        output = "{}\n{}".format(output, output_line.strip())
    return_code = process.poll()
    if return_code is not None:
      for output_line in process.stdout.readlines():
        if output_line.strip() != "":
          if not no_log:
            if not mask_output:
              logger.info("Output : {}".format(output_line.strip()))
            else:
              logger.info("Output : **(Masked)**")
          if output == "":
            output = output_line
          else:
            output = "{}\n{}".format(output, output_line.strip())
      logger.debug("Return Code: {}".format(return_code))
      break
  if cmd_directory != "":
    os.chdir(working_directory)
  return return_code, output


def parse_container_env_args(args):
  container_env_args = []
  for arg in args:
    split_args = arg.split("=")
    logger.debug("Parsing container env args: {}".format(split_args))
    if len(split_args) == 2:
      container_env_args.append({"name": split_args[0], "value": split_args[1]})
    else:
      logger.warning("Skipping Container env argument: {}".format(split_args))
  return container_env_args


def parse_probe_args(args, path):
  split_args = args.split(",")
  prefixes = ["initialDelaySeconds:", "periodSeconds:", "timeoutSeconds:", "failureThreshold:", "successThreshold:"]
  probe_args = []
  logger.debug("Parsing probe args: {}".format(split_args))

  if len(split_args) > 1 and len(split_args) <= 6:
    for index, arg in enumerate(split_args[1:]):
      if arg.isdigit():
        probe_args.append("{} {}".format(prefixes[index], arg))
      else:
        logger.error("Probe argument not an integer: {}".format(arg))
        sys.exit(1)
  elif len(split_args) > 6:
    logger.error("Too many probe arguments: {}".format(split_args))
    sys.exit(1)

  if split_args[0].lower() == "http":
    probe_args.extend(["httpGet:", "  path: {}".format(path)])
  elif split_args[0].lower() == "tcp":
    probe_args.append("tcpSocket:")
  elif split_args[0].lower() == "off":
    return []
  else:
    logger.error("Unrecognized probe argument: {}".format(split_args[0]))
    sys.exit(1)

  return probe_args


def parse_tc_netem_args(cliargs):
  args = {}

  if cliargs.latency > 0:
    args["latency"] = ["delay", "{}ms".format(cliargs.latency)]
  if cliargs.packet_loss > 0:
    args["packet loss"] = ["loss", "{}%".format(cliargs.packet_loss)]
  if cliargs.bandwidth_limit > 0:
    args["bandwidth limit"] = ["rate", "{}kbit".format(cliargs.bandwidth_limit)]

  return args


def apply_tc_netem(interface, start_vlan, end_vlan, impairments, dry_run=False):
  if len(impairments) > 1:
    logger.info("Applying {} impairments".format(", ".join(impairments.keys())))
  elif len(impairments) == 1:
    logger.info("Applying only {} impairment".format(list(impairments.keys())[0]))
  else:
    logger.warn("Invalid state. Applying no impairments.")

  for vlan in range(start_vlan, end_vlan + 1):
    tc_command = ["tc", "qdisc", "add", "dev", "{}.{}".format(interface, vlan), "root", "netem"]
    for impairment in impairments.values():
      tc_command.extend(impairment)
    rc, _ = command(tc_command, dry_run)
    if rc != 0:
      logger.error("Jetlag workload applying impairments failed, tc rc: {}".format(rc))
      sys.exit(1)


def remove_tc_netem(interface, start_vlan, end_vlan, dry_run=False, ignore_errors=False):
  logger.info("Removing bandwidth, latency, and packet loss impairments")
  for vlan in range(start_vlan, end_vlan + 1):
    tc_command = ["tc", "qdisc", "del", "dev", "{}.{}".format(interface, vlan), "root", "netem"]
    rc, _ = command(tc_command, dry_run)
    if rc != 0 and not ignore_errors:
      logger.error("Jetlag workload removing impairments failed, tc rc: {}".format(rc))
      sys.exit(1)


def flap_links_down(interface, start_vlan, end_vlan, dry_run, iptables, network):
  logger.info("Flapping links down")
  for vlan in range(start_vlan, end_vlan + 1):
    if iptables:
      iptables_command = [
          "iptables", "-A", "FORWARD", "-j", "DROP", "-i", "{}.{}".format(interface, vlan), "-d", network]
      rc, _ = command(iptables_command, dry_run)
      if rc != 0:
        logger.error("Jetlag workload, iptables rc: {}".format(rc))
        sys.exit(1)
    else:
      ip_command = ["ip", "link", "set", "{}.{}".format(interface, vlan), "down"]
      rc, _ = command(ip_command, dry_run)
      if rc != 0:
        logger.error("Jetlag workload, ip link set {} down rc: {}".format("{}.{}".format(interface, vlan), rc))
        sys.exit(1)


def flap_links_up(interface, start_vlan, end_vlan, dry_run, iptables, network, ignore_errors=False):
  logger.info("Flapping links up")
  for vlan in range(start_vlan, end_vlan + 1):
    if iptables:
      iptables_command = [
          "iptables", "-D", "FORWARD", "-j", "DROP", "-i", "{}.{}".format(interface, vlan), "-d", network]
      rc, _ = command(iptables_command, dry_run)
      if rc != 0 and not ignore_errors:
        logger.error("Jetlag workload, iptables rc: {}".format(rc))
        sys.exit(1)
    else:
      ip_command = ["ip", "link", "set", "{}.{}".format(interface, vlan), "up"]
      rc, _ = command(ip_command, dry_run)
      if rc != 0 and not ignore_errors:
        logger.error("Jetlag workload, ip link set {} up rc: {}".format("{}.{}".format(interface, vlan), rc))
        sys.exit(1)


def phase_break():
  logger.info("###############################################################################")


def main():
  start_time = time.time()

  default_container_env = [
      "LISTEN_DELAY_SECONDS=20", "LIVENESS_DELAY_SECONDS=10" "READINESS_DELAY_SECONDS=30",
      "RESPONSE_DELAY_MILLISECONDS=50", "LIVENESS_SUCCESS_MAX=60", "READINESS_SUCCESS_MAX=30"
  ]

  parser = argparse.ArgumentParser(
      description="Run the jetlag workload",
      prog="jetlag-workload.py", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

  # Phase arguments
  parser.add_argument("--no-workload-phase", action="store_true", default=False, help="Disables workload phase")
  parser.add_argument("--no-measurement-phase", action="store_true", default=False, help="Disables measurement phase")
  parser.add_argument("--no-cleanup-phase", action="store_true", default=False, help="Disables cleanup workload phase")
  parser.add_argument("--no-index-phase", action="store_true", default=False, help="Disables index phase")

  # Workload arguments
  parser.add_argument("-n", "--namespaces", type=int, default=1, help="Number of namespaces to create")
  parser.add_argument("-d", "--deployments", type=int, default=1, help="Number of deployments per namespace to create")
  parser.add_argument("-l", "--service", action="store_true", default=False, help="Include service per deployment")
  parser.add_argument("-p", "--pods", type=int, default=1, help="Number of pod replicas per deployment to create")
  parser.add_argument("-c", "--containers", type=int, default=1, help="Number of containers per pod replica to create")

  # Workload container image, environment, and resources arguments
  parser.add_argument("-i", "--container-image", type=str,
                      default="quay.io/redhat-performance/test-gohttp-probe:latest", help="The container image to use")
  parser.add_argument('-e', "--container-env", nargs='*', default=default_container_env,
                      help="The container environment variables")
  parser.add_argument("--cpu-requests", type=int, default=0, help="CPU requests per pod (millicores)")
  parser.add_argument("--memory-requests", type=int, default=0, help="Memory requests per pod (MiB)")
  parser.add_argument("--cpu-limits", type=int, default=0, help="CPU limits per pod (millicores)")
  parser.add_argument("--memory-limits", type=int, default=0, help="Memory limits per pod (MiB)")

  # Workload probe arguments
  parser.add_argument("--startup-probe", type=str, default="http,0,10,1,12",
                      help="Container startupProbe configuration")
  parser.add_argument("--liveness-probe", type=str, default="http,0,10,1,3",
                      help="Container livenessProbe configuration")
  parser.add_argument("--readiness-probe", type=str, default="http,0,10,1,3,1",
                      help="Container readinessProbe configuration")
  parser.add_argument("--startup-probe-endpoint", type=str, default="/livez", help="startupProbe endpoint")
  parser.add_argument("--liveness-probe-endpoint", type=str, default="/livez", help="livenessProbe endpoint")
  parser.add_argument("--readiness-probe-endpoint", type=str, default="/readyz", help="readinessProbe endpoint")
  parser.add_argument("--no-probes", action="store_true", default=False, help="Disable all probes")

  # Workload node-selector arguments
  parser.add_argument("--default-selector", type=str, default="jetlag: 'true'", help="Default node-selector")
  parser.add_argument("-s", "--shared-selectors", type=int, default=0, help="How many shared node-selectors to use")
  parser.add_argument("-u", "--unique-selectors", type=int, default=0, help="How many unique node-selectors to use")
  parser.add_argument("-o", "--offset", type=int, default=0, help="Offset for iterated unique node-selectors")
  parser.add_argument(
      "--no-tolerations", action="store_true", default=False, help="Do not include RWN tolerations on pod spec")

  # Measurement arguments
  parser.add_argument("-D", "--duration", type=int, default=30, help="Duration of measurent/impairment phase (Seconds)")
  parser.add_argument("-I", "--interface", type=str, default="ens1f1", help="Interface of vlans to impair")
  parser.add_argument("-S", "--start-vlan", type=int, default=100, help="Starting VLAN off interface")
  parser.add_argument("-E", "--end-vlan", type=int, default=105, help="Ending VLAN off interface")
  parser.add_argument(
      "-L", "--latency", type=int, default=0, help="Amount of latency to add to all VLANed interfaces (milliseconds)")
  parser.add_argument(
      "-P", "--packet-loss", type=int, default=0, help="Percentage of packet loss to add to all VLANed interfaces")
  parser.add_argument(
      "-B", "--bandwidth-limit", type=int, default=0,
      help="Bandwidth limit to apply to all VLANed interfaces (kilobits). 0 for no limit.")
  parser.add_argument("-F", "--link-flap-down", type=int, default=0, help="Time period to flap link down (Seconds)")
  parser.add_argument("-U", "--link-flap-up", type=int, default=0, help="Time period to flap link up (Seconds)")
  parser.add_argument("-T", "--link-flap-firewall", action="store_true", default=False,
                      help="Flaps links via iptables instead of ip link set")
  parser.add_argument("-N", "--link-flap-network", type=str, default="198.18.10.0/24",
                      help="Network to block for iptables link flapping")

  # Indexing arguments
  parser.add_argument(
      "--index-server", type=str, default="", help="ElasticSearch server (Ex https://user:password@example.org:9200)")
  parser.add_argument("--default-index", type=str, default="jetlag-default-test", help="Default index")
  parser.add_argument("--measurements-index", type=str, default="jetlag-measurements-test", help="Measurements index")
  parser.add_argument("--prometheus-url", type=str, default="", help="Cluster prometheus URL")
  parser.add_argument("--prometheus-token", type=str, default="", help="Token to access prometheus")

  # Other arguments
  parser.add_argument("--debug", action="store_true", default=False, help="Set log level debug")
  parser.add_argument("--dry-run", action="store_true", default=False, help="Echos commands instead of executing them")
  parser.add_argument("--reset", action="store_true", default=False, help="Attempts to undo all network impairments")

  cliargs = parser.parse_args()

  if cliargs.debug:
    logger.setLevel(logging.DEBUG)

  phase_break()
  logger.info("Jetlag Workload")
  phase_break()
  logger.debug("CLI Args: {}".format(cliargs))

  container_env_args = parse_container_env_args(cliargs.container_env)

  if cliargs.no_probes:
    cliargs.startup_probe = "off"
    cliargs.liveness_probe = "off"
    cliargs.readiness_probe = "off"
  startup_probe_args = parse_probe_args(cliargs.startup_probe, cliargs.startup_probe_endpoint)
  liveness_probe_args = parse_probe_args(cliargs.liveness_probe, cliargs.liveness_probe_endpoint)
  readiness_probe_args = parse_probe_args(cliargs.readiness_probe, cliargs.readiness_probe_endpoint)

  netem_impairments = parse_tc_netem_args(cliargs)

  if cliargs.reset:
    logger.info("Resetting all network impairments")
    flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run, cliargs.link_flap_firewall,
                  cliargs.link_flap_network, ignore_errors=True)
    remove_tc_netem(
        cliargs.interface,
        cliargs.start_vlan,
        cliargs.end_vlan,
        cliargs.dry_run,
        ignore_errors=True)
    sys.exit(0)

  if cliargs.no_workload_phase and cliargs.no_measurement_phase and cliargs.no_cleanup_phase:
    logger.warning("No meaningful phases enabled. Exiting...")
    sys.exit(0)

  # Validate link flap args
  flap_links = False
  if not cliargs.no_measurement_phase:
    if ((cliargs.link_flap_down == 0 and cliargs.link_flap_up > 0)
       or (cliargs.link_flap_down > 0 and cliargs.link_flap_up == 0)):
      logger.error("Both link flap args (--link-flap-down, --link-flap-up) are required for link flapping. Exiting...")
      sys.exit(1)
    elif cliargs.link_flap_down > 0 and cliargs.link_flap_up > 0:
      if cliargs.link_flap_firewall:
        logger.info("Link flapping enabled via iptables")
        flap_links = True
      else:
        if len(netem_impairments) > 0:
          logger.warning("Netem (Bandwidth/Latency/Packet Loss) impairments are mutually exclusive to link flapping "
                         "impairment via ip link. Use -T flag to combine impairments by using iptables instead of ip "
                         "link. Disabling link flapping.")
        else:
          logger.info("Link flapping enabled via ip link")
          flap_links = True
    else:
      logger.debug("Link flapping impairment disabled")

  # Validate indexing args
  index_measurement_data = False
  index_prometheus_data = False
  index_prometheus_server = ""
  index_prometheus_token = ""
  if not cliargs.index_server == "":
    logger.info("Indexing server is set, indexing measurements enabled")
    index_measurement_data = True
    if not cliargs.no_index_phase:
      logger.info("Indexing phase is enabled, checking prometheus indexing args")
      if cliargs.prometheus_url == "":
        logger.info("Prometheus URL not set, attempting to get prometheus URL with OpenShift client")
        oc_cmd = ["oc", "get", "route/prometheus-k8s", "-n", "openshift-monitoring", "--no-headers", "-o",
                  "custom-columns=HOST:status.ingress[].host"]
        rc, output = command(oc_cmd, cliargs.dry_run)
        if rc != 0:
          logger.warning("Unable to determine prometheus URL via oc, disabling metrics indexing, oc rc: {}".format(rc))
        else:
          index_prometheus_server = "https://{}".format(output)
      else:
        index_prometheus_server = cliargs.index_server
      if cliargs.prometheus_token == "" and not (index_prometheus_server == ""):
        logger.info("Prometheus token not set, attempting to get prometheus "
                    "token with OpenShift client and kubeburner sa")
        oc_cmd = ["oc", "sa", "get-token", "kubeburner"]
        rc, output = command(oc_cmd, cliargs.dry_run, mask_output=True)
        if rc != 0:
          logger.warning("Unable to determine prometheus token via oc, disabling indexing, oc rc: {}".format(rc))
          logger.warning(
              "To remedy, as cluster-admin, run 'kubectl create sa kubeburner' and "
              "'oc adm policy add-cluster-role-to-user -z kubeburner cluster-admin'")
        else:
          index_prometheus_token = output
      else:
        index_prometheus_token = cliargs.prometheus_token
      if index_prometheus_server == "" or index_prometheus_token == "":
        logger.warning("Prometheus server or token unset, disabling prometheus metrics indexing")
        cliargs.no_index_phase = True
      else:
        index_prometheus_data = True
  else:
    logger.info("Indexing server is unset, disabling all indexing")
    cliargs.no_index_phase = True

  logger.info("Scenario Phases:")
  if not cliargs.no_workload_phase:
    if index_measurement_data:
      logger.info("* Workload Phase - Measurement indexing")
    else:
      logger.info("* Workload Phase - No measurement indexing")
    logger.info("  * {} Namespace(s)".format(cliargs.namespaces))
    logger.info("  * {} Deployment(s) per namespace".format(cliargs.deployments))
    if cliargs.service:
      logger.info("  * 1 Service per deployment")
    logger.info("  * {} Pod replica(s) per deployment".format(cliargs.pods))
    logger.info("  * {} Container(s) per pod replica".format(cliargs.containers))
    logger.info("  * Container Image: {}".format(cliargs.container_image))
    logger.info("  * Container CPU: {}m requests, {}m limits".format(cliargs.cpu_requests, cliargs.cpu_limits))
    logger.info(
        "  * Container Memory: {}Mi requests, {}Mi limits".format(cliargs.memory_requests, cliargs.memory_limits))
    logger.info("  * Container Environment: {}".format(container_env_args))
    su_probe = cliargs.startup_probe.split(",")[0]
    l_probe = cliargs.liveness_probe.split(",")[0]
    r_probe = cliargs.readiness_probe.split(",")[0]
    logger.info("  * Probes: startup: {}, liveness: {}, readiness: {}".format(su_probe, l_probe, r_probe))
    logger.info("  * Default Node-Selector: {}".format(cliargs.default_selector))
    logger.info("  * {} Shared Node-Selectors".format(cliargs.shared_selectors))
    logger.info("  * {} Unique Node-Selectors".format(cliargs.unique_selectors))
    if cliargs.no_tolerations:
      logger.info("  * No tolerations")
    else:
      logger.info("  * RWN tolerations")
  if not cliargs.no_measurement_phase:
    logger.info("* Measurement Phase - {}s Duration".format(cliargs.duration))
    if len(netem_impairments) > 0:
      logger.info("  * Bandwidth Limit: {}kbits".format(cliargs.bandwidth_limit))
      logger.info("  * Link Latency: {}ms".format(cliargs.latency))
      logger.info("  * Packet Loss: {}%".format(cliargs.packet_loss))
    if flap_links:
      flapping = "ip link"
      if cliargs.link_flap_firewall:
        flapping = "iptables"
      logger.info("  * Links {}.{} - {}.{}".format(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.interface,
          cliargs.end_vlan))
      logger.info("  * Flap {}s down, {}s up by {}".format(cliargs.link_flap_down, cliargs.link_flap_up, flapping))
    if len(netem_impairments) == 0 and not flap_links:
      logger.info("  * No impairments")
  if not cliargs.no_cleanup_phase:
    if index_measurement_data:
      logger.info("* Cleanup Phase - Measurement indexing")
    else:
      logger.info("* Cleanup Phase - No measurement indexing")
  if not cliargs.no_index_phase:
    logger.info("* Index Phase")

  # Workload UUID is used with both workload and cleanup phases
  workload_UUID = str(uuid.uuid4())

  # Workload Phase
  if not cliargs.no_workload_phase:
    phase_break()
    logger.info("Workload phase starting")
    phase_break()
    workload_start_time = time.time()

    t = Template(workload_create)
    workload_create_rendered = t.render(
        measurements_index=cliargs.measurements_index,
        indexing=index_measurement_data,
        index_server=cliargs.index_server,
        default_index=cliargs.default_index,
        namespaces=cliargs.namespaces,
        deployments=cliargs.deployments,
        pod_replicas=cliargs.pods,
        containers=cliargs.containers,
        container_image=cliargs.container_image,
        cpu_requests=cliargs.cpu_requests,
        cpu_limits=cliargs.cpu_limits,
        memory_requests=cliargs.memory_requests,
        memory_limits=cliargs.memory_limits,
        container_env_args=container_env_args,
        startup_probe_args=startup_probe_args,
        liveness_probe_args=liveness_probe_args,
        readiness_probe_args=readiness_probe_args,
        default_selector=cliargs.default_selector,
        shared_selectors=cliargs.shared_selectors,
        unique_selectors=cliargs.unique_selectors,
        offset=cliargs.offset,
        tolerations=(not cliargs.no_tolerations),
        service=cliargs.service)

    tmp_directory = tempfile.mkdtemp()
    logger.info("Created {}".format(tmp_directory))
    with open("{}/workload-create.yml".format(tmp_directory), "w") as file1:
      file1.writelines(workload_create_rendered)
    logger.info("Created {}/workload-create.yml".format(tmp_directory))
    with open("{}/workload-deployment-selector.yml".format(tmp_directory), "w") as file1:
      file1.writelines(workload_deployment)
    logger.info("Created {}/workload-deployment-selector.yml".format(tmp_directory))
    with open("{}/workload-service.yml".format(tmp_directory), "w") as file1:
      file1.writelines(workload_service)
    logger.info("Created {}/workload-service.yml".format(tmp_directory))

    kb_cmd = ["kube-burner", "init", "-c", "workload-create.yml", "--uuid", workload_UUID]
    rc, _ = command(kb_cmd, cliargs.dry_run, tmp_directory)
    if rc != 0:
      logger.error("Jetlag workload (workload-create.yml) failed, kube-burner rc: {}".format(rc))
      sys.exit(1)
    workload_end_time = time.time()
    logger.info("Workload phase complete")

  # Measurement phase
  if not cliargs.no_measurement_phase:
    phase_break()
    logger.info("Measurement phase starting")
    phase_break()
    measurement_start_time = time.time()
    measurement_expected_end_time = measurement_start_time + cliargs.duration

    logger.info("Measurement phase start: {}, end: {}, duration: {}".format(
        round(measurement_start_time, 1),
        round(measurement_expected_end_time, 1),
        cliargs.duration))

    if len(netem_impairments):
      apply_tc_netem(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.end_vlan,
          netem_impairments,
          cliargs.dry_run)

    if flap_links:
      link_flap_count = 1
      flap_links_down(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run,
                      cliargs.link_flap_firewall, cliargs.link_flap_network)
      next_flap_time = time.time() + cliargs.link_flap_down
      links_down = True

    wait_logger = 0
    current_time = time.time()
    while current_time < measurement_expected_end_time:
      if flap_links:
        if current_time >= next_flap_time:
          if links_down:
            links_down = False
            flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run,
                          cliargs.link_flap_firewall, cliargs.link_flap_network)
            next_flap_time = time.time() + cliargs.link_flap_up
          else:
            links_down = True
            link_flap_count += 1
            flap_links_down(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run,
                            cliargs.link_flap_firewall, cliargs.link_flap_network)
            next_flap_time = time.time() + cliargs.link_flap_down

      time.sleep(.1)
      wait_logger += 1
      if wait_logger >= 100:
        logger.info("Remaining measurement duration: {}".format(round(measurement_expected_end_time - current_time, 1)))
        wait_logger = 0
      current_time = time.time()

    if flap_links:
      flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run,
                    cliargs.link_flap_firewall, cliargs.link_flap_network, True)

    if len(netem_impairments):
      remove_tc_netem(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.end_vlan,
          cliargs.dry_run)
    measurement_end_time = time.time()
    logger.info("Measurement phase complete")

    # Check for pods evicted before cleanup
    phase_break()
    logger.info("Post measurement pod eviction check")
    phase_break()
    ns_pattern = re.compile("jetlag-[0-9]+")
    eviction_pattern = re.compile("Marking for deletion Pod")
    killed_pod = 0
    marked_evictions = 0
    oc_cmd = ["oc", "get", "ev", "-A", "--field-selector", "reason=TaintManagerEviction", "-o", "json"]
    rc, output = command(oc_cmd, cliargs.dry_run, no_log=True)
    if rc != 0:
      logger.error("Jetlag workload, oc get ev rc: {}".format(rc))
      sys.exit(1)
    json_data = json.loads(output)
    for item in json_data['items']:
      if ns_pattern.search(item['involvedObject']['namespace']) and eviction_pattern.search(item['message']):
        marked_evictions += 1
    oc_cmd = ["oc", "get", "ev", "-A", "--field-selector", "reason=Killing", "-o", "json"]
    rc, output = command(oc_cmd, cliargs.dry_run, no_log=True)
    if rc != 0:
      logger.error("Jetlag workload, oc get ev rc: {}".format(rc))
      sys.exit(1)
    json_data = json.loads(output)
    for item in json_data['items']:
      if ns_pattern.search(item['involvedObject']['namespace']):
        killed_pod += 1
    logger.info("jetlag-* pods marked for deletion by Taint Manager: {}".format(marked_evictions))
    logger.info("jetlag-* pods killed: {}".format(killed_pod))

  # Cleanup Phase
  if not cliargs.no_cleanup_phase:
    phase_break()
    logger.info("Cleanup phase starting")
    phase_break()
    cleanup_start_time = time.time()

    t = Template(workload_delete)
    workload_delete_rendered = t.render(
        measurements_index=cliargs.measurements_index,
        indexing=index_measurement_data,
        index_server=cliargs.index_server,
        default_index=cliargs.default_index)

    tmp_directory = tempfile.mkdtemp()
    logger.info("Created {}".format(tmp_directory))
    with open("{}/workload-delete.yml".format(tmp_directory), "w") as file1:
      file1.writelines(workload_delete_rendered)
    logger.info("Created {}/workload-delete.yml".format(tmp_directory))

    kb_cmd = ["kube-burner", "init", "-c", "workload-delete.yml", "--uuid", workload_UUID]
    rc, _ = command(kb_cmd, cliargs.dry_run, tmp_directory)
    if rc != 0:
      logger.error("Jetlag workload (workload-delete.yml) failed, kube-burner rc: {}".format(rc))
      sys.exit(1)
    cleanup_end_time = time.time()
    logger.info("Cleanup phase complete")

  # Index Phase
  if not cliargs.no_index_phase and index_prometheus_data:
    phase_break()
    logger.info("Index phase starting")
    phase_break()
    index_start_time = time.time()

    t = Template(workload_index)
    workload_index_rendered = t.render(
        index_server=cliargs.index_server,
        default_index=cliargs.default_index,
        measurements_index=cliargs.measurements_index)

    tmp_directory = tempfile.mkdtemp()
    logger.info("Created {}".format(tmp_directory))
    with open("{}/workload-index.yml".format(tmp_directory), "w") as file1:
      file1.writelines(workload_index_rendered)
    logger.info("Created {}/workload-index.yml".format(tmp_directory))

    # Copy metrics.yml to tmp directory
    base_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
    metrics_yml_dir = os.path.join(base_dir, "kube-burner", "metrics-aggregated.yaml")
    shutil.copy2(metrics_yml_dir, tmp_directory)
    logger.info("Copied {} to {}".format(metrics_yml_dir, tmp_directory))

    if not cliargs.no_workload_phase:
      start_time = workload_start_time
    elif not cliargs.no_measurement_phase:
      start_time = measurement_start_time
    else:
      start_time = cleanup_start_time

    if not cliargs.no_cleanup_phase:
      end_time = cleanup_end_time
    elif not cliargs.no_measurement_phase:
      end_time = measurement_end_time
    else:
      end_time = workload_end_time

    kb_cmd = [
        "kube-burner", "index", "-c", "workload-index.yml", "--start", str(int(start_time)),
        "--end", str(int(end_time)), "--uuid", workload_UUID, "-u", index_prometheus_server,
        "-m", "{}/metrics-aggregated.yaml".format(tmp_directory), "-t", index_prometheus_token]
    rc, _ = command(kb_cmd, cliargs.dry_run, tmp_directory, mask_arg=16)
    if rc != 0:
      logger.error("Jetlag workload (workload-index.yml) failed, kube-burner rc: {}".format(rc))
      sys.exit(1)

    index_end_time = time.time()
    logger.info("Index phase complete")

  # Dump timings on the test/workload
  phase_break()
  logger.info("Jetlag Workload Stats")
  if flap_links:
    logger.info("* Number of times links flapped down: {}".format(link_flap_count))
  if not cliargs.no_measurement_phase:
    logger.info("* Number of jetlag pods marked for deletion (TaintManagerEviction): {}".format(marked_evictions))
    logger.info("* Number of jetlag pods killed: {}".format(killed_pod))
  if not cliargs.no_workload_phase:
    logger.info("Workload phase duration: {}".format(round(workload_end_time - workload_start_time, 1)))
  if not cliargs.no_measurement_phase:
    logger.info("Measurement phase duration: {}".format(round(measurement_end_time - measurement_start_time, 1)))
  if not cliargs.no_cleanup_phase:
    logger.info("Cleanup phase duration: {}".format(round(cleanup_end_time - cleanup_start_time, 1)))
  if not cliargs.no_index_phase:
    logger.info("Index phase duration: {}".format(round(index_end_time - index_start_time, 1)))
  total_time = time.time() - start_time
  logger.info("Total duration: {}".format(round(total_time, 1)))
  if not cliargs.no_index_phase:
    logger.info("Workload UUID: {}".format(workload_UUID))


if __name__ == '__main__':
  sys.exit(main())
