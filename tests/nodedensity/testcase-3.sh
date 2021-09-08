#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 3 - Single Namespace, Deploys vs Pods - Max Pods

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 180"
csvfile="--csv-file tc3-$(date -u +%Y%m%d-%H%M%S).csv"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 3 Start"
echo "****************************************************************************************************************************************"

#
# gohttp image
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.1 - 1 namespace, 1 deploy, 1000 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.1.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-gohttp" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.1 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.2 - 1 namespace, 2 deploys, 500 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.2.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-2d-500p-1c-gohttp" -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.2 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.3 - 1 namespace, 4 deploys, 250 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.3.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-4d-250p-1c-gohttp" -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.3 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.4 - 1 namespace, 10 deploys, 100 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.4.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-10d-100p-1c-gohttp" -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.4 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.5 - 1 namespace, 20 deploys, 50 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.5.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-20d-50p-1c-gohttp" -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.5 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.6 - 1 namespace, 50 deploys, 20 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.6.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-50d-20p-1c-gohttp" -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.6 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.7 - 1 namespace, 100 deploys, 10 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.7.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-100d-10p-1c-gohttp" -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.7 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.8 - 1 namespace, 250 deploys, 4 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.8.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-250d-4p-1c-gohttp" -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.8 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.9 - 1 namespace, 500 deploys, 2 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.9.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-500d-2p-1c-gohttp" -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.9 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.10 - 1 namespace, 1000 deploys, 1 pod, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.10.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1000d-1p-1c-gohttp" -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.10 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# pause image
#
image="-i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.11 - 1 namespace, 1 deploy, 1000 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.11.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-pause" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.11 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.12 - 1 namespace, 2 deploys, 500 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.12.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-2d-500p-1c-pause" -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.12 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.13 - 1 namespace, 4 deploys, 250 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.13.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-4d-250p-1c-pause" -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.13 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.14 - 1 namespace, 10 deploys, 100 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.14.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-10d-100p-1c-pause" -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.14 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.15 - 1 namespace, 20 deploys, 50 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.15.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-20d-50p-1c-pause" -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.15 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.16 - 1 namespace, 50 deploys, 20 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.16.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-50d-20p-1c-pause" -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.16 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.17 - 1 namespace, 100 deploys, 10 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.17.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-100d-10p-1c-pause" -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.17 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.18 - 1 namespace, 250 deploys, 4 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.18.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-250d-4p-1c-pause" -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.18 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.19 - 1 namespace, 500 deploys, 2 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.19.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-500d-2p-1c-pause" -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.19 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.20 - 1 namespace, 1000 deploys, 1 pod, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.20.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1000d-1p-1c-pause" -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.20 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# hello-kubernetes image
#
image="-i 'quay.io/akrzos/hello-kubernetes' --no-probes"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.21 - 1 namespace, 1 deploy, 1000 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.21.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-hello" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.21 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.22 - 1 namespace, 2 deploys, 500 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.22.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-2d-500p-1c-hello" -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.22 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.23 - 1 namespace, 4 deploys, 250 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.23.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-4d-250p-1c-hello" -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.23 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.24 - 1 namespace, 10 deploys, 100 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.24.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-10d-100p-1c-hello" -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.24 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.25 - 1 namespace, 20 deploys, 50 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.25.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-20d-50p-1c-hello" -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.25 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.26 - 1 namespace, 50 deploys, 20 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.26.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-50d-20p-1c-hello" -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.26 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.27 - 1 namespace, 100 deploys, 10 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.27.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-100d-10p-1c-hello" -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.27 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.28 - 1 namespace, 250 deploys, 4 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.28.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-250d-4p-1c-hello" -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.28 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.29 - 1 namespace, 500 deploys, 2 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.29.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-500d-2p-1c-hello" -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.29 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.30 - 1 namespace, 1000 deploys, 1 pod, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.30.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1000d-1p-1c-hello" -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 3.30 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 3 Complete"
