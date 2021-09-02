#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 2 - Max configmaps and secrets per container

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 300"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

#
# ConfigMaps
#

# jetlag workload - 1 container, probes, 1 service, 1 configmap, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.1.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 1 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 10 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.2.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 10 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 40 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.3.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 40 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 80 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.4.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 80 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 160 configmaps, 0 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.5.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 160 --secrets 0  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# Secrets now
#

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 1 secret
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.6.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 1  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 10 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.7.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 10  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 40 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.8.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 40  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 80 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.9.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 80  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 0 configmaps, 160 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.10.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 0 --secrets 160  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# ConfigMaps and Secrets
#

# jetlag workload - 1 container, probes, 1 service, 1 configmap, 1 secret
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.11.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 1 --secrets 1  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 10 configmaps, 10 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.12.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 10 --secrets 10  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 40 configmaps, 40 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.13.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 40 --secrets 40  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 80 configmaps, 80 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.14.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 80 --secrets 80  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 1 container, probes, 1 service, 160 configmaps, 160 secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-2.15.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l -m 160 --secrets 160  ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

echo "Test Case 2 Complete"
