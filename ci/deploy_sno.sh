#!/bin/bash -e

# User variables
BASTION=${BASTION:-"f30-h01-000-r640.rdu2.scalelab.redhat.com"}
ID_FILE=${ID_FILE:-~/.ssh/id_scalelab}
PULL_SECRET=${PULL_SECRET:-"pull_secret.txt"}
RHEL_RELEASE=${RHEL_RELEASE:-"8.9"}

# Lab & cluster infrastructure variables
LAB_NAME=${LAB_NAME:-"scalelab"}
CLOUD_NAME=${CLOUD_NAME:-"cloud02"}
CLUSTER_TYPE=${CLUSTER_TYPE:-"sno"}
SNO_NODE_COUNT=${SNO_NODE_COUNT:-"1"}
#ocp_release_image
#openshift_version
#smcipmitool_url

# Bastion node variables
#bastion_lab_interface
#bastion_controlplane_interface
#controlplane_lab_interface

# Debugging aids and other shorthand:
#  - If the script is invoked with -x (the "xtrace" option), then arrange to
#    pass that option to the remote execution; also, don't redirect output to
#    the bit bucket -- let it show on the terminal.
#  - If DEBUG is set, then echo the commands instead of executing them.
xtrace=$(set -o | sed -nE -e '/xtrace/ s/xtrace *\t*on/-x/p')
if [[ -n ${xtrace} ]]; then B=''; else B='2>/dev/null'; fi
ON_BASTION="${N} ssh -i ${ID_FILE} root@${BASTION} /bin/bash -e ${xtrace}"
N=${DEBUG:+'echo [DRY-RUN] '}

cat <<- __EOF__
	Deploying an Openshift Cluster:
	  bastion node: ${BASTION}
	  update the bastion OS version to: RHEL ${RHEL_RELEASE}
	  SSH ID file: ${ID_FILE}.

	  LAB_NAME: ${LAB_NAME}
	  CLOUD_NAME: ${CLOUD_NAME}
	  CLUSTER_TYPE: ${CLUSTER_TYPE}
	  SNO_NODE_COUNT: ${SNO_NODE_COUNT}

	NOTE:  You may be prompted by ssh-copy-id twice to enter the root password
	for the bastion, once now and once after the node reboots.

__EOF__

echo -e "\nCopying local SSH key to the bastion."
${N} ssh-copy-id -i "${ID_FILE}" "root@${BASTION}" >/dev/null 2>&1

echo -e "\nChecking bastion OS version."
current_release=$(${ON_BASTION} <<< 'cat /etc/redhat-release' | ${N} awk '{ print $6 }')
if [[ "${current_release}" != "${RHEL_RELEASE}" ]]; then
    ${N} echo -e "\nUpdating to bastion OS from ${current_release} to ${RHEL_RELEASE}."
    # shellcheck disable=SC2087
    ${ON_BASTION}  <<- __EOF__
				${N} ./update-latest-rhel-release.sh ${RHEL_RELEASE}
				${N} dnf update -y
				${N} reboot
		__EOF__

    TIMEFORMAT="elapsed %3lR; proceeding."
    echo -en "\nWaiting for reboot (this may take several minutes)"
    time (until ${ON_BASTION} <<< "exit 0" ${B}; do
        echo Result: $?
        echo -n .
        sleep 10
    done)
    TIMEFORMAT=
fi

echo -e "\nInstalling tools, local SSH key, and Jetlag."
# shellcheck disable=SC2087
${ON_BASTION} <<- __EOF__
		${N} sed -E -e 's/(.*)/\nBastion OS: \1/' /etc/redhat-release
		${N} dnf install tmux git python3-pip sshpass -y
		${N} rm -rf /root/.ssh/id_rsa /root/.ssh/id_rsa.pub /root/jetlag
		${N} ssh-keygen -q -N "" -f /root/.ssh/id_rsa
		${N} cat /root/.ssh/authorized_keys /root/.ssh/id_rsa.pub | ${N} tee /root/.ssh/authorized_keys.new >/dev/null
		${N} mv -f --backup=simple --suffix=.prev /root/.ssh/authorized_keys.new /root/.ssh/authorized_keys
		${N} git clone https://github.com/redhat-performance/jetlag.git && cd jetlag || exit
__EOF__

echo -e "\nCopying pull secret."
${N} scp -i "${ID_FILE}" "${PULL_SECRET}" "root@${BASTION}:jetlag/pull_secret.txt"

echo -e "\nSetting up"
# shellcheck disable=SC2087
${ON_BASTION} <<- __EOF__
		${N} cd jetlag
		${N} source bootstrap.sh
		${N} sed -E \
		  -e '/lab:/ s/lab:.*/lab: ${LAB_NAME}/' \
		  -e '/lab_cloud:/ s/lab_cloud:.*/lab_cloud: ${CLOUD_NAME}/' \
		  -e '/cluster_type:/ s/cluster_type:.*/cluster_type: ${CLUSTER_TYPE}/' \
		  -e '/sno_node_count:/ s/sno_node_count:.*/sno_node_count: ${SNO_NODE_COUNT}/' \
		  ansible/vars/all.sample.yml | ${N} tee ansible/vars/all.yml
		${N} ansible-playbook ansible/create-inventory.yml
		${N} ansible-playbook -i ansible/inventory/cloud99.local ansible/setup-bastion.yml
__EOF__

echo -e "\nDeploying the cluster."
${ON_BASTION} <<- __EOF__
		${N} cd jetlag
		${N} source .ansible/bin/activate
		${N} ansible-playbook -i ansible/inventory/cloud02.local ansible/sno-deploy.yml
__EOF__
