#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 1 - Max Containers with Service and Probes

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 180"
csvfile="--csv-file tc1-$1-$(date -u +%Y%m%d-%H%M%S).csv"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 1 Start"
echo "****************************************************************************************************************************************"

options=("--no-probes" "-l --no-probes" "-l")
tc_titles=("no service, no probes" "1 service, no probes" "1 service, probes")
csv_titles=("0s-no_probes" "1s-no_probes" "1s-probes")
containers="1 10 40 80 160"
test_index=0
for (( arg_index=0; arg_index<${#options[@]}; arg_index++)); do
  for container_count in ${containers}; do
    test_index=$((${test_index} + 1))
    echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.${test_index} - ${container_count} container, ${tc_titles[$arg_index]}, no configmaps or secrets"
    logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.${test_index}.log"
    ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${container_count}c-${csv_titles[$arg_index]}" -n 1 -d 1 -p 1 -c ${container_count} ${options[$arg_index]} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
    echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.${test_index} complete, sleeping ${sleep_period}"
    sleep ${sleep_period}
    echo "****************************************************************************************************************************************"
  done
done

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 1 Complete"
