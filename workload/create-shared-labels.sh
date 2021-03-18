#!/usr/bin/env bash

usage() {
  echo "Creates labels shared among group of nodes via nodeselector"
  echo "Usage: create-shared-labels.sh <nodeselector> <label_count>"
  echo "Example: create-shared-labels.sh rwn=true 10"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

selector=$1
label_count=$2

for i in `seq 1 ${label_count}`; do
  echo "$(date -u +"%y%m%d-%H%M%S") :: Creating label rwns-${i}"
  echo "oc label no -l ${selector} rwns-${i}=true"
  oc label no -l ${selector} rwns-${i}=true
done
