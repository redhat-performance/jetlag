#!/usr/bin/env bash
# Test Case 1 - Guaranteed/BestEffort w/ w/o tolerations

mkdir -p ../logs
sleep_period=120
small_pod_count=1400

# RWN Workload - Guaranteed Large/Small Pods
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.1.log"
../../workload/jetlag-workload.py -n 12 --cpu-limits 29000 --memory-limits 122880 -s 0 -u 0 --no-tolerations -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.2.log"
../../workload/jetlag-workload.py -n ${small_pod_count} --cpu-limits 100 --memory-limits 1024 -s 0 -u 0 --no-tolerations -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Best Effort Few/Many Pods
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.3.log"
../../workload/jetlag-workload.py -n 12 -s 0 -u 0 --no-tolerations -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.4.log"
../../workload/jetlag-workload.py -n ${small_pod_count} -s 0 -u 0 --no-tolerations -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Large/Small Pods with tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.5.log"
../../workload/jetlag-workload.py -n 12 --cpu-limits 29000 --memory-limits 122880 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.6.log"
../../workload/jetlag-workload.py -n ${small_pod_count} --cpu-limits 100 --memory-limits 1024 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Best Effort Few/Many Pods with tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.7.log"
../../workload/jetlag-workload.py -n 12 -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-1.8.log"
../../workload/jetlag-workload.py -n ${small_pod_count} -s 0 -u 0 -D 60 -L 0 -P 0 -F 0 -U 0 ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 1 Complete"
