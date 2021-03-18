#!/usr/bin/env bash

usage() {
  echo "Clears shared/unique labels off group of nodes via nodeselector"
  echo "Usage: clear-labels.sh <nodeselector> <label_count>"
  echo "Example: clear-labels.sh rwn=true 10"
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

selector=$1
label_count=$2

for i in `seq 1 ${label_count}`; do
  echo "$(date -u +"%y%m%d-%H%M%S") :: Clearing labels rwns-${i} rwn-${i}"
  echo "oc label no -l ${selector} rwns-${i}- rwn-${i}-"
  oc label no -l ${selector} rwns-${i}- rwn-${i}-
done
