#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

echo "Removing sriov network ..."
[ -e ${MANIFEST_DIR}/sriov-network.yaml ] && oc delete -f ${MANIFEST_DIR}/sriov-network.yaml
echo "Removing sriov network: done"

sleep 1

echo "Removing SriovNetworkNodePolicy ..."
[ -e ${MANIFEST_DIR}/sriov-nic-policy.yaml ] && oc delete -f ${MANIFEST_DIR}/sriov-nic-policy.yaml
echo "Removing SriovNetworkNodePolicy: done"

# is VF down?
if [[ "${WAIT_MCP}" == "true" ]]; then
    count=30
    while exec_over_ssh ${BAREMETAL_WORKER} "ip link show ${DU_SRIOV_INTERFACE}" | egrep '^\s+vf\s'; do 
        count=$((count -1))
        if ((count == 0)); then
            echo "SRIOV VF still up!"
            exit 1
        fi
        echo "waiting for sriov VF removed ..."
        sleep 5
    done
    echo "SRIOV VF: removed"
fi
