#!/bin/sh

#
# Debug tips: start and stop PTP master and check
#   oc logs linuxptp-daemon-hdbfm -c linuxptp-daemon-container
#

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

mkdir -p ${MANIFEST_DIR}/

###### install ptp operator #####
channel=$(get_ocp_channel)
# skip if ptp operator subscription already exists 
if ! oc get Subscription ptp-operator-subscription -n openshift-ptp 2>/dev/null; then 
    echo "generating ${MANIFEST_DIR}/sub-ptp.yaml ..."
    #export OCP_CHANNEL=$(get_ocp_channel)
    if [[ "${channel}" == "4.10" ]]; then
    	export OCP_CHANNEL=stable
    else
    	export OCP_CHANNEL=$(channel)
    fi

    envsubst < templates/sub-ptp.yaml.template > ${MANIFEST_DIR}/sub-ptp.yaml
    oc create -f ${MANIFEST_DIR}/sub-ptp.yaml
    echo "generating ${MANIFEST_DIR}/sub-ptp.yaml: done"
fi

wait_pod_in_namespace openshift-ptp

echo "generating ${MANIFEST_DIR}/ptp-config.yaml ..."
if [[ "${SNO}" == "false" ]]; then
    export MCP=worker-cnf
else
    export MCP=master
fi

if [ $(ver ${channel}) -ge $(ver 4.10) ] ; then
   envsubst < templates/ptp-config-410.yaml.template > ${MANIFEST_DIR}/ptp-config.yaml
else
   envsubst < templates/ptp-config.yaml.template > ${MANIFEST_DIR}/ptp-config.yaml
fi
echo "generating ${MANIFEST_DIR}/ptp-config.yaml: done"

##### apply ptp-config ######
if ! oc get PtpConfig ptp-du -n openshift-ptp 2>/dev/null; then
    echo "create PtpConfig ..."
    oc create -f ${MANIFEST_DIR}/ptp-config.yaml
    echo "create PtpConfig: done"
fi

# disable chronyd
echo "disable chronyd ..."
envsubst < templates/disable-chronyd.yaml.template > ${MANIFEST_DIR}/disable-chronyd.yaml

# Tip: HN while debug ptp, consider disabling chronyd one time and not re-enable chronyd 
# in cleanup. Then you can invoke install/cleanup over and over again w/o long wait.
echo "Tip: consider one-time chronyd disabling during PTP DEBUG"

if ! oc get MachineConfig disable-chronyd 0>/dev/null; then
oc create -f ${MANIFEST_DIR}/disable-chronyd.yaml
fi

if [[ "${SNO}" == "true" ]]; then
   echo "Being SNO, node will reboot and API be silent ..."
fi

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

echo "disable chronyd: done" 
