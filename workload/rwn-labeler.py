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
import logging
import subprocess
import sys
import time

logging.basicConfig(level=logging.INFO, format='%(asctime)s : %(levelname)s : %(message)s')
logger = logging.getLogger('RWN-Labeler')
logging.Formatter.converter = time.gmtime


def command(cmd, dry_run):
  if dry_run:
    cmd.insert(0, "echo")
  logger.info("Command: {}".format(" ".join(cmd)))
  process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True)
  output = ""
  while True:
    output_line = process.stdout.readline()
    if output_line.strip() != "":
      logger.info("Output : {}".format(output_line.strip()))
      if output == "":
        output = output_line.strip()
      else:
        output = "{}\n{}".format(output, output_line.strip())
    time.sleep(.1)
    return_code = process.poll()
    if return_code is not None:
      for output_line in process.stdout.readlines():
        if output_line.strip() != "":
          logger.info("Output : {}".format(output_line.strip()))
          if output == "":
            output = output_line
          else:
            output = "{}\n{}".format(output, output_line.strip())
      logger.debug("Return Code: {}".format(return_code))
      break
  return return_code, output


def get_nodes(label_selector, dry_run):
  oc_command = ["oc", "get", "no", "--no-headers", "-l", label_selector, "-o", "name"]
  rc, output = command(oc_command, dry_run)
  if rc != 0:
    logger.error("get_nodes oc rc: {}".format(rc))
    sys.exit(1)
  return output.split("\n")


def shared_labels(create, label_count, label_prefix, label_selector, dry_run):
  label_command = ["oc", "label", "no", "-l", label_selector]
  for i in range(1, label_count + 1):
    if create:
      label_command.append("{}-{}=true".format(label_prefix, i))
    else:
      label_command.append("{}-{}-".format(label_prefix, i))
  logger.info("{}".format(label_command))
  rc, _ = command(label_command, dry_run)
  if rc != 0:
    logger.error("shared_labels oc rc: {}".format(rc))
    sys.exit(1)


def unique_labels(create, label_count, label_prefix, label_selector, dry_run):
  nodes = get_nodes(label_selector, dry_run)
  offset = len(nodes)
  range_end = offset * label_count + 1
  for node_index in range(offset):
    label_command = ["oc", "label", nodes[node_index]]
    for i in range(node_index + 1, range_end, offset):
      if create:
        label_command.append("{}-{}=true".format(label_prefix, i))
      else:
        label_command.append("{}-{}-".format(label_prefix, i))
    logger.info("{}".format(label_command))
    rc, _ = command(label_command, dry_run)
    if rc != 0:
      logger.error("unique_labels oc rc: {}".format(rc))
      sys.exit(1)


def phase_break():
  logger.info("###############################################################################")


def main():
  start_time = time.time()
  parser = argparse.ArgumentParser(
      description="Label nodes for the rwn workload",
      prog="rwn-labeler.py", formatter_class=argparse.ArgumentDefaultsHelpFormatter)

  parser.add_argument("-c", "--count", type=int, default=100, help="Count of labels")

  parser.add_argument("-s", "--shared", action="store_true", default=False, help="Create labels shared among nodes")
  parser.add_argument("-u", "--unique", action="store_true", default=False, help="Create labels unique among nodes")

  parser.add_argument("--clear", action="store_true", default=False, help="Clear labels")

  parser.add_argument("-l", "--label-selector", type=str, default="rwn=true", help="Label to select nodes for labeling")
  parser.add_argument("--shared-prefix", type=str, default="rwns", help="Shared label prefix")
  parser.add_argument("--unique-prefix", type=str, default="rwnu", help="Unique label prefix")

  parser.add_argument("-d", "--debug", action="store_true", default=False, help="Set log level debug")
  parser.add_argument("--dry-run", action="store_true", default=False, help="Echos commands instead of executing them")

  cliargs = parser.parse_args()

  if cliargs.debug:
    logger.setLevel(logging.DEBUG)

  phase_break()
  logger.info("RWN Labeler")
  phase_break()
  logger.debug("CLI Args: {}".format(cliargs))

  if not cliargs.clear:
    if cliargs.shared:
      logger.info("Create {} shared labels".format(cliargs.count))
      shared_labels(True, cliargs.count, cliargs.shared_prefix, cliargs.label_selector, cliargs.dry_run)
    if cliargs.unique:
      logger.info("Create {} unique labels".format(cliargs.count))
      unique_labels(True, cliargs.count, cliargs.unique_prefix, cliargs.label_selector, cliargs.dry_run)
    if not cliargs.shared and not cliargs.unique:
      logger.error("Specify which labels 'type' to create/clear -s or -u")
      return 1
  else:
    if cliargs.shared:
      logger.info("Clear {} shared labels".format(cliargs.count))
      shared_labels(False, cliargs.count, cliargs.shared_prefix, cliargs.label_selector, cliargs.dry_run)
    if cliargs.unique:
      logger.info("Clear {} unique labels".format(cliargs.count))
      unique_labels(False, cliargs.count, cliargs.unique_prefix, cliargs.label_selector, cliargs.dry_run)
    if not cliargs.shared and not cliargs.unique:
      logger.error("Unspecified which labels to clear")
      return 1
  logger.info("Total Time: {}".format(round(time.time() - start_time, 2)))


if __name__ == '__main__':
  sys.exit(main())
