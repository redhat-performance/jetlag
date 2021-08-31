#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 4 - Single Deploy, Namespaces vs Pods - Max Pods

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 300"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

#
# gohttp image
#

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.1.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1 -p 1000 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.2.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 2 -p 500 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.3.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 4 -p 250 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.4.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 10 -p 100 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.5.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 20 -p 50 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.6.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 50 -p 20 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.7.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 100 -p 10 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.8.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 250 -p 4 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.9.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 500 -p 2 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.10.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1000 -p 1 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# pause image
#
image="-i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes"

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.11.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.12.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.13.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.14.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.15.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.16.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.17.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.18.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.19.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.20.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# hello-kubernetes image
#
image="-i 'quay.io/akrzos/hello-kubernetes' --no-probes"

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.21.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.22.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.23.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.24.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.25.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.26.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.27.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.28.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.29.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-4.30.log"
../../workload/jetlag-workload.py ${dryrun} -d 1 -n 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

echo "Test Case 4 Complete"
