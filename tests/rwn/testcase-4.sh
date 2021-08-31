#!/usr/bin/env bash
# Test Case 4 - Latency and Packet Loss

mkdir -p ../logs
sleep_period=120
pods=1400

# RWN Workload - Guaranteed Small Pods, 1000 labels 50ms latency w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.1.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 50 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.2.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 50 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 200ms latency w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.3.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 200 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.4.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 200 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 1000ms latency w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.5.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 1000 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.6.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 1000 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 3000ms latency w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.7.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 3000 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.8.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 3000 -P 0 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 2% Packet Loss w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.9.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 2 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.10.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 2 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 5% Packet Loss w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.11.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 5 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.12.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 5 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 10% Packet Loss w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.13.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 10 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.14.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 10 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# RWN Workload - Guaranteed Small Pods, 1000 labels 20% Packet Loss w/ and w/o tolerations
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.15.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 --no-tolerations -D 1800 -L 0 -P 20 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-rwn-4.16.log"
../../workload/jetlag-workload.py -n ${pods} --cpu-limits 100 --memory-limits 1024 -s 1000 -u 1000 -D 1800 -L 0 -P 20 -F 0 -U 0 -T ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"

echo "Test Case 4 Complete"
