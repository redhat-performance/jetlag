#!/usr/bin/env bash
# Test Case 1 - Guaranteed/BestEffort w/ w/o tolerations

mkdir -p logs
sleep_period=120
small_pod_count=1400

# RWN Workload - Guaranteed Large/Small Pods
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.1.log"
../workload/rwn-workload.py -i 12 -c 29 -m 120 -s 0 -u 0 -n -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.2.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 100m -m 1 -s 0 -u 0 -n -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Best Effort Few/Many Pods
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.3.log"
../workload/rwn-workload.py -i 12 -c 0 -m 0 -s 0 -u 0 -n -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.4.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 0 -m 0 -s 0 -u 0 -n -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods with tolerations
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.5.log"
../workload/rwn-workload.py -i 12 -c 29 -m 120 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.6.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 100m -m 1 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Best Effort Few/Many Pods with tolerations
logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.7.log"
../workload/rwn-workload.py -i 12 -c 0 -m 0 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="logs/$(date -u +%Y%m%d-%H%M%S)-testcase-1.8.log"
../workload/rwn-workload.py -i ${small_pod_count} -c 0 -m 0 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 1 Complete"
