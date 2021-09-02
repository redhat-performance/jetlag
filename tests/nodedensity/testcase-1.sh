#!/usr/bin/env bash
# Node Density Enhanced Testing
# Test Case 1 - Max Containers with Service and Probes

mkdir -p ../logs
sleep_period=120

gohttp_env_vars="-e LISTEN_DELAY_SECONDS=0 LIVENESS_DELAY_SECONDS=0 READINESS_DELAY_SECONDS=0 RESPONSE_DELAY_MILLISECONDS=0 LIVENESS_SUCCESS_MAX=0 READINESS_SUCCESS_MAX=0"
measurement="-D 300"

# Debug/Test entire Run
# dryrun="--dry-run"
# measurement="--no-measurement-phase"
# sleep_period=1

#
# Max Containers
#

# jetlag workload - 1 container, no probes, no service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.1.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 10 containers, no probes, no service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.2.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 10 --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 40 containers, no probes, no service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.3.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 40 --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 80 containers, no probes, no service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.4.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 80 --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 160 containers, no probes, no service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.5.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 160 --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# Add a service
#

# jetlag workload - 1 container, no probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.6.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 10 containers, no probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.7.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 10 -l --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 40 containers, no probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.8.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 40 -l --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 80 containers, no probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.9.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 80 -l --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 160 containers, no probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.10.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 160 -l --no-probes ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

#
# Add Probes
#

# jetlag workload - 1 container, probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.11.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 1 -l ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 10 containers, probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.12.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 10 -l ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 40 containers, probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.13.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 40 -l ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 80 containers, probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.14.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 80 -l ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

# jetlag workload - 160 containers, probes, 1 service, no configmaps or secrets
logfile="../logs/$(date -u +%Y%m%d-%H%M%S)-nodedensity-1.15.log"
../../workload/jetlag-workload.py ${dryrun} -n 1 -d 1 -p 1 -c 160 -l ${gohttp_env_vars} ${measurement} ${RWN_INDEX_ARGS} 2>&1 | tee ${logfile}
echo "****************************************************************************************************************************************"
sleep ${sleep_period}

echo "Test Case 1 Complete"
