#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 3 - Single Namespace, Deploys vs Pods - Max Pods

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
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.1.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.2.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.3.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.4.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.5.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.6.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.7.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.8.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.9.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.10.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# pause image
#
image="-i 'gcr.io/google_containers/pause-amd64:3.0' --no-probes"

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.11.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.12.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.13.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.14.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.15.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.16.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.17.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.18.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.19.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.20.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# hello-kubernetes image
#
image="-i 'quay.io/akrzos/hello-kubernetes' --no-probes"

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.21.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1000 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.22.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 2 -p 500 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.23.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 4 -p 250 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.24.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 10 -p 100 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.25.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 20 -p 50 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.26.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 50 -p 20 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.27.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 100 -p 10 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.28.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 250 -p 4 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.29.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 500 -p 2 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-3.30.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1000 -p 1 -c 1 -l -m 0 --secrets 0 ${image} ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

echo "Test Case 3 Complete"
