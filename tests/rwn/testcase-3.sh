#!/usr/bin/env bash
# Test Case 3 - Link Flapping
# Link Flap 30/30/1800 = 30s down, 30s up, 1800s duration

mkdir -p ../logs
sleep_period=120
pods=1400

# RWN Workload - Guaranteed Small Pods, 1000 labels link flap 30/30/1800 w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.1.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 0 -F 30 -U 30 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.2.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 0 -F 30 -U 30 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels link flap 30/300/1800 w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.3.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 0 -F 30 -U 300 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.4.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 0 -F 30 -U 300 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels link flap 300/30/1800 w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.5.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 0 -F 300 -U 30 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.6.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 0 -F 300 -U 30 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels link flap 600/30/1800 w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.7.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 0 -F 600 -U 60 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-3.8.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 0 -F 600 -U 60 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 3 Complete"
