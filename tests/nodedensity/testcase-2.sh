#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 2 - Max configmaps and secrets per container

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 180"
csvfile="--csv-file tc2-$1-$(date -u +%Y%m%d-%H%M%S).csv"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 2 Start"
echo "****************************************************************************************************************************************"


# ConfigMaps
obj_counts="1 10 40 80 160"
test_index=0
for obj_count in ${obj_counts}; do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} - 1 container, 1 service, probes, ${obj_count} configmap(s), 0 secrets"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.${test_index}.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${obj_count}cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m ${obj_count} --secrets 0 ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

# Secrets
for obj_count in ${obj_counts}; do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} - 1 container, 1 service, probes, 0 configmaps, ${obj_count} secret(s)"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.${test_index}.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-${obj_count}s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets ${obj_count} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

# ConfigMaps and Secrets
for obj_count in ${obj_counts}; do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} - 1 container, 1 service, probes, ${obj_count} configmap(s), ${obj_count} secret(s)"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.${test_index}.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${obj_count}cm-${obj_count}s" -n 1 -d 1 -p 1 -c 1 -l -m ${obj_count} --secrets ${obj_count} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 2 Complete"
