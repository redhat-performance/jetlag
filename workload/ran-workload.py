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
import logging
import os
import subprocess
import sys
import tempfile
import time
import uuid

ran_create = """---
global:
  writeToFile: true
  metricsDirectory: collected-metrics
  measurements:
  - name: podLatency
    esIndex: kube-burner

  indexerConfig:
    enabled: false
    esServers: [https://user:password@es-instance.example.org:9200]
    insecureSkipVerify: true
    defaultIndex: kube-burner
    type: elastic

jobs:
  - name: ran
    jobType: create
    jobIterations: {{ iterations }}
    qps: 20
    burst: 40
    namespacedIterations: true
    cleanup: true
    namespace: ran
    podWait: false
    waitWhenFinished: true
    verifyObjects: true
    errorOnVerify: false
    jobIterationDelay: 0s
    jobPause: 0s
    objects:
    - objectTemplate: ran-deployment-selector.yml
      replicas: 1
      inputVars:
        image: gcr.io/google_containers/pause-amd64:3.0
        resources:
          requests:
            cpu: {{ cpu }}
            memory: {{ mem }}Gi
          limits:
            cpu: {{ cpu }}
            memory: {{ mem }}Gi
        shared_selectors: {{ shared_selectors }}
        unique_selectors: {{ unique_selectors }}
        unique_selector_offset: {{ offset }}
        tolerations: {{ tolerations }}
"""

ran_delete = """---
global:
  writeToFile: true
  metricsDirectory: collected-metrics
  measurements:
    - name: podLatency
      esIndex: kube-burner

  indexerConfig:
    enabled: false
    esServers: [https://user:password@es-instance.example.org:9200]
    insecureSkipVerify: true
    defaultIndex: kube-burner
    type: elastic

jobs:
  - name: cleanup-ran
    jobType: delete
    waitForDeletion: true
    qps: 10
    burst: 20
    objects:

    - kind: Deployment
      labelSelector: {kube-burner-job: ran}
      apiVersion: apps/v1

    - kind: Namespace
      labelSelector: {kube-burner-job: ran}
      apiVersion: v1
"""

ran_deployment = """---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ran-{{ .Iteration }}-{{ .Replica }}-{{.JobName }}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ran-{{ .Iteration }}-{{ .Replica }}
  strategy:
    resources: {}
  template:
    metadata:
      labels:
        app: ran-{{ .Iteration }}-{{ .Replica }}
    spec:
      containers:
      - name: pause-pod
        image: {{ .image }}
        resources:
          requests:
            cpu: {{ .resources.requests.cpu }}
            memory: {{ .resources.requests.memory }}
          limits:
            cpu: {{ .resources.limits.cpu }}
            memory: {{ .resources.limits.memory }}
      nodeSelector:
        rwn: "true"
        {{ range $index, $element := sequence 1 .shared_selectors }}
        rwns-{{ $element }}: "true"
        {{ end }}
        {{ $data := . }}
        {{ range $index, $element := sequence 1 $data.unique_selectors }}
        {{ $first := multiply $data.unique_selector_offset $index }}
        rwnu-{{ add $first $data.Iteration }}: "true"
        {{ end }}
      {{ if .tolerations }}
      tolerations:
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 0
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 0
      - key: "node.kubernetes.io/unschedulable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 0
      {{ end }}
"""

logging.basicConfig(level=logging.INFO, format='%(asctime)s : %(levelname)s : %(message)s')
logger = logging.getLogger('RAN-Workload')
logging.Formatter.converter = time.gmtime


def command(cmd, dry_run=False, cmd_directory=""):
  if cmd_directory != "":
    logger.debug("Command Directory: {}".format(cmd_directory))
    working_directory = os.getcwd()
    os.chdir(cmd_directory)
  if dry_run:
    cmd.insert(0, "echo")
  logger.info("Command: {}".format(" ".join(cmd)))
  process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)

  while True:
    output = process.stdout.readline()
    if output.strip() != "":
      logger.info("Output : {}".format(output.strip()))
    time.sleep(.1)
    return_code = process.poll()
    if return_code is not None:
      for output in process.stdout.readlines():
        if output.strip() != "":
          logger.info("Output : {}".format(output.strip()))
      logger.debug("Return Code: {}".format(return_code))
      break
  if cmd_directory != "":
    os.chdir(working_directory)
  return return_code


def apply_latency_packet_loss(interface, start_vlan, end_vlan, latency, packet_loss, dry_run=False):
  tc_latency = []
  tc_loss = []
  if latency > 0 and packet_loss > 0:
    logger.info("Applying latency and packet loss impairment")
  elif latency > 0 and packet_loss <= 0:
    logger.info("Applying only latency impairment")
  elif latency <= 0 and packet_loss > 0:
    logger.info("Applying only packet loss impairment")

  if latency > 0:
    tc_latency = ["delay", "{}ms".format(latency)]
  if packet_loss > 0:
    tc_loss = ["loss", "{}%".format(packet_loss)]
  for vlan in range(start_vlan, end_vlan + 1):
    tc_command = ["tc", "qdisc", "add", "dev", "{}.{}".format(interface, vlan), "root", "netem"]
    tc_command.extend(tc_loss)
    tc_command.extend(tc_latency)
    rc = command(tc_command, dry_run)
    if rc != 0:
      logger.error("RAN workload applying latency and packet loss failed, tc rc: {}".format(rc))
      sys.exit(1)


def remove_latency_packet_loss(interface, start_vlan, end_vlan, latency, packet_loss, dry_run=False):
  logger.info("Removing latency and packet loss impairments")
  for vlan in range(start_vlan, end_vlan + 1):
    tc_command = ["tc", "qdisc", "del", "dev", "{}.{}".format(interface, vlan), "root", "netem"]
    rc = command(tc_command, dry_run)
    if rc != 0:
      logger.error("RAN workload removing latency and packet loss failed, tc rc: {}".format(rc))
      sys.exit(1)


def flap_links_down(interface, start_vlan, end_vlan, dry_run):
  logger.info("Flapping links down")
  for vlan in range(start_vlan, end_vlan + 1):
    ip_command = ["ip", "link", "set", "{}.{}".format(interface, vlan), "down"]
    rc = command(ip_command, dry_run)
    if rc != 0:
      logger.error("RAN workload, ip link set {} down rc: {}".format("{}.{}".format(interface, vlan), rc))
      sys.exit(1)


def flap_links_up(interface, start_vlan, end_vlan, dry_run):
  logger.info("Flapping links up")
  for vlan in range(start_vlan, end_vlan + 1):
    ip_command = ["ip", "link", "set", "{}.{}".format(interface, vlan), "up"]
    rc = command(ip_command, dry_run)
    if rc != 0:
      logger.error("RAN workload, ip link set {} up rc: {}".format("{}.{}".format(interface, vlan), rc))
      sys.exit(1)


def phase_break():
  logger.info("###############################################################################")


def main():
  start_time = time.time()
  parser = argparse.ArgumentParser(
      description="Run the ran workload with or without network impairments",
      prog="ran-workload.py")

  # Disable a phase arguements
  parser.add_argument("--no-workload-phase", action="store_true", default=False, help="Disables workload phase")
  parser.add_argument("--no-impairment-phase", action="store_true", default=False, help="Disables impairment phase")
  parser.add_argument("--no-cleanup-phase", action="store_true", default=False, help="Disables cleanup workload phase")
  parser.add_argument("--no-index-phase", action="store_true", default=False, help="Disables index phase")

  # Workload arguements
  parser.add_argument("-i", "--iterations", type=int, default=12, help="Number of RAN namespaces to create")
  parser.add_argument("-c", "--cpu", type=int, default=29, help="Guaranteed CPU requests/limits per pod (Cores)")
  parser.add_argument("-m", "--mem", type=int, default=120, help="Guaranteed Memory requests/limits per pod (GiB)")
  parser.add_argument("-s", "--shared-selectors", type=int, default=100, help="How many shared node-selectors to use")
  parser.add_argument("-u", "--unique-selectors", type=int, default=100, help="How many unique node-selectors to use")
  parser.add_argument("-o", "--offset", type=int, default=6, help="Offset for iterated unique node-selectors")
  parser.add_argument(
      "-n", "--no-tolerations", action="store_true", default=False, help="Do not include tolerations on pod spec")

  # Impairment arguements
  parser.add_argument("-D", "--duration", type=int, default=30, help="Duration of impairment (Seconds)")
  parser.add_argument("-I", "--interface", type=str, default="ens1f1", help="Interface of vlans to impair (Ex ens1f1)")
  parser.add_argument("-S", "--start-vlan", type=int, default=100, help="Starting VLAN off interface (Ex 100)")
  parser.add_argument("-E", "--end-vlan", type=int, default=105, help="Ending VLAN off interface (Ex 105)")
  parser.add_argument(
      "-L", "--latency", type=int, default=0, help="Number of milliseconds of latency to add to all VLANed interfaces")
  parser.add_argument(
      "-P", "--packet-loss", type=int, default=0, help="Percentage of packet loss to add to all VLANed interfaces")
  parser.add_argument("-F", "--link-flap-down", type=int, default=0, help="Time period to flap link down (Seconds)")
  parser.add_argument("-U", "--link-flap-up", type=int, default=0, help="Time period to flap link up (Seconds)")

  # Other arguements
  parser.add_argument("-d", "--debug", action="store_true", default=False, help="Set log level debug")
  parser.add_argument("--dry-run", action="store_true", default=False, help="Echos commands instead of executing them")
  parser.add_argument("--reset", action="store_true", default=False, help="Attempts to undo all network impairments")

  cliargs = parser.parse_args()

  if cliargs.debug:
    logger.setLevel(logging.DEBUG)

  phase_break()
  logger.info("RAN Workload")
  phase_break()
  logger.debug("CLI Args: {}".format(cliargs))

  if cliargs.reset:
    logger.info("Resetting all network impairments")
    flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run)
    remove_latency_packet_loss(
        cliargs.interface,
        cliargs.start_vlan,
        cliargs.end_vlan,
        cliargs.latency,
        cliargs.packet_loss,
        cliargs.dry_run)
    sys.exit(0)

  if cliargs.no_workload_phase and cliargs.no_cleanup_phase and cliargs.no_impairment_phase:
    logger.warning("No meaningful phases enabled. Exiting...")
    sys.exit(0)

  # Validate impairment args here
  flap_links = False
  if not cliargs.no_impairment_phase:
    if ((cliargs.link_flap_down == 0 and cliargs.link_flap_up > 0)
       or (cliargs.link_flap_down > 0 and cliargs.link_flap_up == 0)):
      logger.error("Both link flap args (--link-flap-down, --link-flap-up) are required for link flapping. Exiting...")
      sys.exit(1)
    elif cliargs.link_flap_down > 0 and cliargs.link_flap_up > 0:
      if cliargs.latency > 0 or cliargs.packet_loss > 0:
        logger.warning(
            "Latency/Packet Loss impairments are mutually exclusive to link flapping impairment."
            "Disabling link flapping.")
      else:
        logger.debug("Link flapping enabled")
        flap_links = True
    else:
      logger.debug("Link flapping impairment disabled")

    logger.info("Network Impairments: ")
    if cliargs.latency > 0 or cliargs.packet_loss > 0:
      logger.info(" * Link Latency: {}ms".format(cliargs.latency))
      logger.info(" * Packet Loss: {}%".format(cliargs.packet_loss))
    elif flap_links:
      logger.info(" * Links {}.{} - {}.{}".format(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.interface,
          cliargs.end_vlan))
      logger.info(" * Flap {}s down, {}s up".format(cliargs.link_flap_down, cliargs.link_flap_up))
    else:
      logger.info(" * None")

  # Workload UUID is used with both workload and cleanup phases
  workload_UUID = str(uuid.uuid4())

  # Workload Phase
  if not cliargs.no_workload_phase:
    phase_break()
    logger.info("Workload phase starting")
    phase_break()
    workload_start_time = time.time()

    t = Template(ran_create)
    ran_create_rendered = t.render(
        iterations=cliargs.iterations,
        cpu=cliargs.cpu,
        mem=cliargs.mem,
        shared_selectors=cliargs.shared_selectors,
        unique_selectors=cliargs.unique_selectors,
        offset=cliargs.offset,
        tolerations=(not cliargs.no_tolerations))

    tmp_directory = tempfile.mkdtemp()
    logger.info("Created {}".format(tmp_directory))
    with open("{}/ran-create.yml".format(tmp_directory), "w") as file1:
      file1.writelines(ran_create_rendered)
    logger.info("Created {}/ran-create.yml".format(tmp_directory))
    with open("{}/ran-deployment-selector.yml".format(tmp_directory), "w") as file1:
      file1.writelines(ran_deployment)
    logger.info("Created {}/ran-deployment-selector.yml".format(tmp_directory))

    kb_cmd = ["kube-burner", "init", "-c", "ran-create.yml", "--uuid", workload_UUID]
    rc = command(kb_cmd, cliargs.dry_run, tmp_directory)
    if rc != 0:
      logger.error("RAN workload (ran-create.yml) failed, kube-burner rc: {}".format(rc))
      sys.exit(1)
    workload_end_time = time.time()
    logger.info("Workload phase complete")

  # Impairment phase
  if not cliargs.no_impairment_phase:
    phase_break()
    logger.info("Impairment phase starting")
    phase_break()
    impairment_start_time = time.time()
    impairment_expected_end_time = impairment_start_time + cliargs.duration

    logger.info("Impairment start: {}, end: {}, duration: {}".format(
        round(impairment_start_time, 1),
        round(impairment_expected_end_time, 1),
        cliargs.duration))

    if cliargs.latency > 0 or cliargs.packet_loss > 0:
      apply_latency_packet_loss(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.end_vlan,
          cliargs.latency,
          cliargs.packet_loss,
          cliargs.dry_run)

    if flap_links:
      link_flap_count = 1
      flap_links_down(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run)
      next_flap_time = time.time() + cliargs.link_flap_down
      links_down = True

    wait_logger = 0
    current_time = time.time()
    while current_time < impairment_expected_end_time:
      if flap_links:
        if current_time >= next_flap_time:
          if links_down:
            links_down = False
            flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run)
            next_flap_time = time.time() + cliargs.link_flap_up
          else:
            links_down = True
            link_flap_count += 1
            flap_links_down(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run)
            next_flap_time = time.time() + cliargs.link_flap_down

      time.sleep(.1)
      wait_logger += 1
      if wait_logger >= 100:
        logger.info("Remaining impairment duration: {}".format(round(impairment_expected_end_time - current_time, 1)))
        wait_logger = 0
      current_time = time.time()

    if flap_links:
      flap_links_up(cliargs.interface, cliargs.start_vlan, cliargs.end_vlan, cliargs.dry_run)

    if cliargs.latency > 0 or cliargs.packet_loss > 0:
      remove_latency_packet_loss(
          cliargs.interface,
          cliargs.start_vlan,
          cliargs.end_vlan,
          cliargs.latency,
          cliargs.packet_loss,
          cliargs.dry_run)
    impairment_end_time = time.time()
    logger.info("Impairment phase complete")

  # Cleanup Phase
  if not cliargs.no_cleanup_phase:
    phase_break()
    logger.info("Cleanup phase starting")
    phase_break()
    cleanup_start_time = time.time()

    tmp_directory = tempfile.mkdtemp()
    logger.info("Created {}".format(tmp_directory))
    with open("{}/ran-delete.yml".format(tmp_directory), "w") as file1:
      file1.writelines(ran_delete)
    logger.info("Created {}/ran-delete.yml".format(tmp_directory))

    kb_cmd = ["kube-burner", "init", "-c", "ran-delete.yml", "--uuid", workload_UUID]
    rc = command(kb_cmd, cliargs.dry_run, tmp_directory)
    if rc != 0:
      logger.error("RAN workload (ran-delete.yml) failed, kube-burner rc: {}".format(rc))
      sys.exit(1)
    cleanup_end_time = time.time()
    logger.info("Cleanup phase complete")

  # Index Phase
  if not cliargs.no_index_phase:
    phase_break()
    logger.info("Index phase starting")
    phase_break()
    index_start_time = time.time()
    logger.warning("Not implemented yet")
    index_end_time = time.time()
    logger.info("Index phase complete")

  # Dump timings on the test/workload
  phase_break()
  logger.info("Stats")
  if flap_links:
    logger.info("Links flapped down {} times".format(link_flap_count))
  if not cliargs.no_workload_phase:
    logger.info("Workload phase duration: {}".format(round(workload_end_time - workload_start_time, 1)))
  if not cliargs.no_impairment_phase:
    logger.info("Impairment phase duration: {}".format(round(impairment_end_time - impairment_start_time, 1)))
  if not cliargs.no_cleanup_phase:
    logger.info("Cleanup phase duration: {}".format(round(cleanup_end_time - cleanup_start_time, 1)))
  if not cliargs.no_index_phase:
    logger.info("Index phase duration: {}".format(round(index_end_time - index_start_time, 1)))
  logger.info("Total duration: {}".format(round(time.time() - start_time, 1)))


if __name__ == '__main__':
  sys.exit(main())
