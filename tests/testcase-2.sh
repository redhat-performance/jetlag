#!/usr/bin/env bash
# Test Case 2 - Labels

mkdir -p logs
sleep_period=120
small_pod_count=1400

# RWN Workload - Guaranteed Large/Small Pods 50 shared, 50 unique labels
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.1.log"
../workload/rwn-workload.py -i 12 -c 29 -m 120 -s 50 -u 50 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.2.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 100m -m 1 -s 50 -u 50 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods 100 shared, 100 unique labels
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.3.log"
../workload/rwn-workload.py -i 12 -c 29 -m 120 -s 100 -u 100 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.4.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 100m -m 1 -s 100 -u 100 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods 1000 shared, 1000 unique labels
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.5.log"
../workload/rwn-workload.py -i 12 -c 29 -m 120 -s 1000 -u 1000 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-2.6.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 100m -m 1 -s 1000 -u 1000 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 2 Complete"
