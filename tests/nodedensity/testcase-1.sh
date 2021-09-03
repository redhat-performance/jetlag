#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 1 - Max Containers with Service and Probes

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 180"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 1 Start"
echo "****************************************************************************************************************************************"

#
# Max Containers
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.1 - 1 container, no service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.1.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "1c-0s-no_probes" -n 1 -d 1 -p 1 -c 1 --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.1 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.2 - 10 containers, no service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.2.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "10c-0s-no_probes" -n 1 -d 1 -p 1 -c 10 --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.2 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.3 - 40 containers, no service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.3.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "40c-0s-no_probes" -n 1 -d 1 -p 1 -c 40 --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.3 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.4 - 80 containers, no service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.4.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "80c-0s-no_probes" -n 1 -d 1 -p 1 -c 80 --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.4 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.5 - 160 containers, no service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.5.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "160c-0s-no_probes" -n 1 -d 1 -p 1 -c 160 --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.5 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# Add a service
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.6 - 1 container, 1 service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.6.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "1c-1s-no_probes" -n 1 -d 1 -p 1 -c 1 -l --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.6 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.7 - 10 containers, 1 service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.7.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "10c-1s-no_probes" -n 1 -d 1 -p 1 -c 10 -l --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.7 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.8 - 40 containers, 1 service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.8.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "40c-1s-no_probes" -n 1 -d 1 -p 1 -c 40 -l --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.8 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.9 - 80 containers, 1 service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.9.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "80c-1s-no_probes" -n 1 -d 1 -p 1 -c 80 -l --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.9 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.10 - 160 containers, 1 service, no probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.10.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "160c-1s-no_probes" -n 1 -d 1 -p 1 -c 160 -l --no-probes ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.10 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

#
# Add Probes
#

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.11 - 1 container, 1 service, probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.11.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "1c-1s-probes" -n 1 -d 1 -p 1 -c 1 -l ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.11 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.12 - 10 containers, 1 service, probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.12.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "10c-1s-probes" -n 1 -d 1 -p 1 -c 10 -l ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.12 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.13 - 40 containers, 1 service, probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.13.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "40c-1s-probes" -n 1 -d 1 -p 1 -c 40 -l ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.13 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.14 - 80 containers, 1 service, probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.14.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "80c-1s-probes" -n 1 -d 1 -p 1 -c 80 -l ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.14 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.15 - 160 containers, 1 service, probes, no configmaps or secrets"
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.15.log"
../../workload/jetlag-workload.py ${dryrun} --csv-title "160c-1s-probes" -n 1 -d 1 -p 1 -c 160 -l ${gohttp_env_vars} ${measurement} ${INDEX_ARGS} &> ${logfile}
echo "$(date -u +%Y%m%d-%H%M%S) - node density 1.15 complete, sleeping ${sleep_period}"
sleep ${sleep_period}
echo "****************************************************************************************************************************************"

echo "$(date -u +%Y%m%d-%H%M%S) - Test Case 1 Complete"
