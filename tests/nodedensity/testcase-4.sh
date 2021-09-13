#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 4 - Single Deploy, Namespaces vs Pods - Max Pods

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
echo "****************************************************************************************************************************************"

#
# gohttp image
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.1 - 1 namespace, 1 deploy, 1000 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.1.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-gohttp" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.1 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.2 - 2 namespaces, 1 deploy, 500 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.2.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "2n-1d-500p-1c-gohttp" -n 2 -d 1 -p 500 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.2 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.3 - 4 namespaces, 1 deploy, 250 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.3.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "4n-1d-250p-1c-gohttp" -n 4 -d 1 -p 250 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.3 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.4 - 10 namespaces, 1 deploy, 100 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.4.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "10n-1d-100p-1c-gohttp" -n 10 -d 1 -p 100 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.4 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.5 - 20 namespaces, 1 deploy, 50 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.5.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "20n-1d-50p-1c-gohttp" -n 20 -d 1 -p 50 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.5 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.6 - 50 namespaces, 1 deploy, 20 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.6.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "50n-1d-20p-1c-gohttp" -n 50 -d 1 -p 20 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.6 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.7 - 100 namespaces, 1 deploy, 10 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.7.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "100n-1d-10p-1c-gohttp" -n 100 -d 1 -p 10 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.7 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.8 - 250 namespaces, 1 deploy, 4 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.8.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "250n-1d-4p-1c-gohttp" -n 250 -d 1 -p 4 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.8 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.9 - 500 namespaces, 1 deploy, 2 pods, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.9.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "500n-1d-2p-1c-gohttp" -n 500 -d 1 -p 2 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.9 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.10 - 1000 namespaces, 1 deploy, 1 pod, 1 container (gohttp), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.10.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1000n-1d-1p-1c-gohttp" -n 1000 -d 1 -p 1 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.10 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# pause image
#
image="-i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.11 - 1 namespace, 1 deploy, 1000 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.11.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-pause" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.11 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.12 - 2 namespaces, 1 deploy, 500 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.12.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "2n-1d-500p-1c-pause" -n 2 -d 1 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.12 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.13 - 4 namespaces, 1 deploy, 250 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.13.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "4n-1d-250p-1c-pause" -n 4 -d 1 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.13 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.14 - 10 namespaces, 1 deploy, 100 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.14.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "10n-1d-100p-1c-pause" -n 10 -d 1 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.14 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.15 - 20 namespaces, 1 deploy, 50 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.15.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "20n-1d-50p-1c-pause" -n 20 -d 1 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.15 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.16 - 50 namespaces, 1 deploy, 20 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.16.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "50n-1d-20p-1c-pause" -n 50 -d 1 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.16 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.17 - 100 namespaces, 1 deploy, 10 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.17.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "100n-1d-10p-1c-pause" -n 100 -d 1 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.17 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.18 - 250 namespaces, 1 deploy, 4 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.18.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "250n-1d-4p-1c-pause" -n 250 -d 1 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.18 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.19 - 500 namespaces, 1 deploy, 2 pods, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.19.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "500n-1d-2p-1c-pause" -n 500 -d 1 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.19 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.20 - 1000 namespaces, 1 deploy, 1 pod, 1 container (pause), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.20.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1000n-1d-1p-1c-pause" -n 1000 -d 1 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.20 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# hello-kubernetes image
#
image="-i 'quay.io/akrzos/hello-kubernetes' --no-probes"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.21 - 1 namespace, 1 deploy, 1000 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.21.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1n-1d-1000p-1c-hello" -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.21 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.22 - 2 namespaces, 1 deploy, 500 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.22.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "2n-1d-500p-1c-hello" -n 2 -d 1 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.22 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.23 - 4 namespaces, 1 deploy, 250 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.23.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "4n-1d-250p-1c-hello" -n 4 -d 1 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.23 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.24 - 10 namespaces, 1 deploy, 100 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.24.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "10n-1d-100p-1c-hello" -n 10 -d 1 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.24 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.25 - 20 namespaces, 1 deploy, 50 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.25.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "20n-1d-50p-1c-hello" -n 20 -d 1 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.25 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.26 - 50 namespaces, 1 deploy, 20 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.26.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "50n-1d-20p-1c-hello" -n 50 -d 1 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.26 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.27 - 100 namespaces, 1 deploy, 10 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.27.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "100n-1d-10p-1c-hello" -n 100 -d 1 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.27 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.28 - 250 namespaces, 1 deploy, 4 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.28.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "250n-1d-4p-1c-hello" -n 250 -d 1 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.28 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.29 - 500 namespaces, 1 deploy, 2 pods, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.29.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "500n-1d-2p-1c-hello" -n 500 -d 1 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.29 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.30 - 1 deploy, 1000 namespaces, 1 deploy, 1 pod, 1 container (hello-kubernetes), 1 service, probes, 0 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.30.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1000n-1d-1p-1c-hello" -n 1000 -d 1 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 4.30 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 4 Complete"
