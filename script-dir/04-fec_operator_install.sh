#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

echo "validate DU_FEC ..."
if [[ "${DU_FEC}" == "SW" ]]; then
    echo "using software FEC, no FEC to setup"
    exit 0
elif [[ "${DU_FEC}" == "ACC100" ]]; then
    expected_device_id="8086:0d5c"
elif [[ "${DU_FEC}" == "N3000" ]]; then
    expected_device_id="8086:0d8f"
else
    echo "unsupported env DU_FEC: ${DU_FEC}"
fi

device_id=$(exec_over_ssh ${BAREMETAL_WORKER} "lspci -s ${DU_FEC_PCI} -n" | sed -n -r 's/.* (8086:[[:alnum:]]+).*/\1/p')
if [[ "${device_id}" != "${expected_device_id}" ]]; then
    echo "env DU_FEC=${DU_FEC}, actual device: ${device_id}, expecting ${expected_device_id}"
    exit 1
fi
echo "validate DU_FEC: done"

mkdir -p ${MANIFEST_DIR}/

echo "generating ${MANIFEST_DIR}/create-fec-vf.yaml ..."
if [[ "${DU_FEC}" == "ACC100" ]]; then
    template="templates/create-vf-acc100.yaml.template"
elif [[ "${DU_FEC}" == "N3000" ]]; then
    template="templates/create-vf-n3000.yaml.template"
else
    echo "invalid env DU_FEC: ${DU_FEC}!"
    exit 1
fi

envsubst < ${template} > ${MANIFEST_DIR}/create-fec-vf.yaml
echo "generating ${MANIFEST_DIR}/create-fec-vf.yaml: done"

oc label --overwrite node ${BAREMETAL_WORKER} fpga.intel.com/intel-accelerator-present="" 

# skip if fec operator subscription already exists 
if ! oc get Subscription sriov-fec-subscription -n vran-acceleration-operators 2>/dev/null; then 
    echo "generating ${MANIFEST_DIR}/sub-fec.yaml ..."
    envsubst < templates/sub-fec.yaml.template > ${MANIFEST_DIR}/sub-fec.yaml
    oc create -f ${MANIFEST_DIR}/sub-fec.yaml
    echo "generating ${MANIFEST_DIR}/sub-fec.yaml: done"
fi

wait_named_deployement_in_namespace vran-acceleration-operators sriov-fec-controller-manager

# workaround for fec operator bug
# oc delete SriovFecClusterConfig config -n vran-acceleration-operators 2>/dev/null || true

if ! oc get SriovFecClusterConfig config -n vran-acceleration-operators 2>/dev/null; then
    echo "create SriovFecClusterConfig ..."
    oc create -f ${MANIFEST_DIR}/create-fec-vf.yaml
    echo "create SriovFecClusterConfig: done"
fi

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

echo "create FEC VF: done"
