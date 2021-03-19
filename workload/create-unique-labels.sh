#!/usr/bin/env bash

usage() {
  echo "Creates labels per node distributed across all nodes that are selected"
  echo "Usage: create-unique-labels.sh <label_selector> <label_count>"
  echo "Example: create-unique-labels.sh rwn=true 10"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

selector=$1
label_count=$2
loop_end=$(($2-1))

# All labels in format rwnu-X where X is the index of the label
prefix="rwnu"

raw_nodes=$(oc get no -l rwn=true --no-headers -o name)
nodes=($raw_nodes)
node_count=${#nodes[@]}

echo "Distributing ${label_count} labels across ${node_count}"

for i in `seq 0 ${loop_end}`; do
  label_index=$(($i+1))
  node_index=$(($i%${node_count}))
  echo "$(date -u +"%y%m%d-%H%M%S") :: Creating label ${prefix}-${label_index}"
  echo "oc label ${nodes[node_index]} ${prefix}-${label_index}=true"
  oc label ${nodes[node_index]} ${prefix}-${label_index}=true
done
