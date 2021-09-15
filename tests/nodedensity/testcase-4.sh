#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 4 - Single Deploy, Namespaces vs Pods - Max Pods

nodes=$(oc get no -l jetlag=true --no-headers | wc -l)
node_pods=500
total_pods=$((${nodes} * ${node_pods}))

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 180"
csvfile="--csv-file tc4-$1-$(date -u +%Y%m%d-%H%M%S).csv"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 4 Start"
echo "$(date -u +%Y%m%d-%H%M%S) - Total Pod Count (Nodes * 500pods/node) :: ${nodes} * ${node_pods} = ${total_pods}"
echo "****************************************************************************************************************************************"

# gohttp image
namespaces=("1" "10" "50" "100" "500" "${total_pods}")
pods=("${total_pods}" "$((${total_pods} / 10))" "$((${total_pods} / 50))" "$((${total_pods} / 100))" "$((${total_pods} / 500))" "1")
test_index=0
for (( index=0; index<${#namespaces[@]}; index++)); do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} - ${namespaces[${index}]} namespace(s), 1 deploy, ${pods[${index}]} pod(s), 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.1.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${namespaces[${index}]}n-1d-${pods[${index}]}p-1c-gohttp" -n ${namespaces[${index}]} -d 1 -p ${pods[${index}]} -c 1 -l -m 0 --secrets 0 ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

# pause image
image="-i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes"
for (( index=0; index<${#namespaces[@]}; index++)); do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} - ${namespaces[${index}]} namespace(s), 1 deploy, ${pods[${index}]} pod(s), 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.1.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${namespaces[${index}]}n-1d-${pods[${index}]}p-1c-pause" -n ${namespaces[${index}]} -d 1 -p ${pods[${index}]} -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

# hello-kubernetes image
image="-i 'quay.io/akrzos/hello-kubernetes' --no-probes"
for (( index=0; index<${#namespaces[@]}; index++)); do
  test_index=$((${test_index} + 1))
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} - ${namespaces[${index}]} namespace(s), 1 deploy, ${pods[${index}]} pod(s), 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
  logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.1.log"
  ../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "${namespaces[${index}]}n-1d-${pods[${index}]}p-1c-hello" -n ${namespaces[${index}]} -d 1 -p ${pods[${index}]} -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
  echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.${test_index} complete, sleeping ${sleep_period}"
  sleep ${sleep_period}
  echo "****************************************************************************************************************************************"
done

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 4 Complete"
