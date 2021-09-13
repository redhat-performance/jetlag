#!/usr/bin/env bash

version=$(oc version -o json | jq -r '.openshiftVersion')
network="sdn"
#network="ovn"

time ./testcase-1.sh ${version}-${network} | tee ${version}-${network}-tc1.log
sleep 300
time ./testcase-2.sh ${version}-${network} | tee ${version}-${network}-tc2.log
sleep 300
time ./testcase-3.sh ${version}-${network} | tee ${version}-${network}-tc3.log
sleep 300
time ./testcase-4.sh ${version}-${network} | tee ${version}-${network}-tc4.log
