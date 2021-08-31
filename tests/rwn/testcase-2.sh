#!/usr/bin/env bash
# Test Case 2 - Labels

mkdir -p ../logs
sleep_period=120
small_pod_count=1400

# RWN Workload - Guaranteed Large/Small Pods 50 shared, 50 unique labels
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.1.log"
../../workload/jetlag-workload.py -n 12 --cpu-limits 29000 --memory-limits 122880 -s 50 -u 50 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.2.log"
../../workload/jetlag-workload.py -n ${small_pod_count} --cpu-limits 100 --memory-limits 1024 -s 50 -u 50 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods 100 shared, 100 unique labels
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.3.log"
../../workload/jetlag-workload.py -n 12 --cpu-limits 29000 --memory-limits 122880 -s 100 -u 100 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.4.log"
../../workload/jetlag-workload.py -n ${small_pod_count} --cpu-limits 100 --memory-limits 1024 -s 100 -u 100 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods 1000 shared, 1000 unique labels
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.5.log"
../../workload/jetlag-workload.py -n 12 --cpu-limits 29000 --memory-limits 122880 -s 1000 -u 1000 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-2.6.log"
../../workload/jetlag-workload.py -n ${small_pod_count} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 2 Complete"
