#!/usr/bin/env bash

usage() {
  echo "Creates labels across group of nodes via nodeselector"
  echo "Usage: create-shared-labels.sh <nodeselector> <label_count>"
  echo "Example: create-shared-labels.sh rwn=true 10"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

selector=$1
label_count=$2

# All labels in format rwns-X where X is the index of the label
prefix="rwns"

for i in `seq 1 ${label_count}`; do
  echo "$(date -u +"%y%m%d-%H%M%S") :: Creating label ${prefix}-${i}"
  echo "oc label no -l ${selector} ${prefix}-${i}=true"
  oc label no -l ${selector} ${prefix}-${i}=true
done
