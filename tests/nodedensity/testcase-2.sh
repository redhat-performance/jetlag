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

#
# ConfigMaps
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.1 - 1 container, 1 service, probes, 1 configmap, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.1.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m 1 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.1 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.2 - 1 container, 1 service, probes, 10 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.2.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "10cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m 10 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.2 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.3 - 1 container, 1 service, probes, 40 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.3.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "40cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m 40 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.3 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.4 - 1 container, 1 service, probes, 80 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.4.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "80cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m 80 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.4 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.5 - 1 container, 1 service, probes, 160 configmaps, 0 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.5.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "160cm-0s" -n 1 -d 1 -p 1 -c 1 -l -m 160 --secrets 0  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.5 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# Secrets now
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.6 - 1 container, 1 service, probes, 0 configmaps, 1 secret"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.6.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-1s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 1  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.6 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.7 - 1 container, 1 service, probes, 0 configmaps, 10 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.7.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-10s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 10  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.7 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.8 - 1 container, 1 service, probes, 0 configmaps, 40 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.8.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-40s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 40  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.8 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.9 - 1 container, 1 service, probes, 0 configmaps, 80 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.9.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-80s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 80  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.9 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.10 - 1 container, 1 service, probes, 0 configmaps, 160 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.10.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "0cm-160s" -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 160  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.10 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# ConfigMaps and Secrets
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.11 - 1 container, 1 service, probes, 1 configmap, 1 secret"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.11.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "1cm-1s" -n 1 -d 1 -p 1 -c 1 -l -m 1 --secrets 1  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.11 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.12 - 1 container, 1 service, probes, 10 configmaps, 10 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.12.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "10cm-10s" -n 1 -d 1 -p 1 -c 1 -l -m 10 --secrets 10  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.12 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.13 - 1 container, 1 service, probes, 40 configmaps, 40 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.13.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "40cm-40s" -n 1 -d 1 -p 1 -c 1 -l -m 40 --secrets 40  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.13 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.14 - 1 container, 1 service, probes, 80 configmaps, 80 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.14.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "80cm-80s" -n 1 -d 1 -p 1 -c 1 -l -m 80 --secrets 80  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.14 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.15 - 1 container, 1 service, probes, 160 configmaps, 160 secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.15.log"
../../workload/jetlag-workload.py ${dryrun} ${csvfile} --csv-title "160cm-160s" -n 1 -d 1 -p 1 -c 1 -l -m 160 --secrets 160  ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 2.15 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 2 Complete"
