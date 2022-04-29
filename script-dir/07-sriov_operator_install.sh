#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

oc label --overwrite node ${BAREMETAL_WORKER} feature.node.kubernetes.io/network-sriov.capable=true

mkdir -p ${MANIFEST_DIR}/

###### install sriov operator #####
# skip if sriov operator subscription already exists 
if ! oc get Subscription sriov-network-operator-subsription -n openshift-sriov-network-operator 2>/dev/null; then 
    #// Installing SR-IOV Network Operator done
    echo "generating ${MANIFEST_DIR}/sub-sriov.yaml ..."
    export OCP_CHANNEL=$(get_ocp_channel)
    envsubst < templates/sub-sriov.yaml.template > ${MANIFEST_DIR}/sub-sriov.yaml
    oc create -f ${MANIFEST_DIR}/sub-sriov.yaml
    echo "generating ${MANIFEST_DIR}/sub-sriov.yaml: done"
fi

wait_pod_in_namespace openshift-sriov-network-operator

if [[ "${SNO}" == "false" ]]; then
   echo "disable drain since this is SNO"
   oc patch sriovoperatorconfig default --type=merge -n openshift-sriov-network-operator --patch '{ "spec": { "disableDrain": true } }'
fi

# // Default is fine for us. No need to Configuring the SR-IOV Network Operator.

echo "Acquiring SRIOV interface PCI info from worker node ${BAREMETAL_WORKER} ..."
export DU_SRIOV_INTERFACE_PCI=$(exec_over_ssh ${BAREMETAL_WORKER} "ethtool -i ${DU_SRIOV_INTERFACE}" | awk '/bus-info:/{print $NF;}')
echo "Acquiring SRIOV interface PCI info from worker node ${BAREMETAL_WORKER}: done"

echo "generating ${MANIFEST_DIR}/sriov-nic-policy.yaml ..."
envsubst < templates/sriov-nic-policy.yaml.template > ${MANIFEST_DIR}/sriov-nic-policy.yaml
echo "generating ${MANIFEST_DIR}/sriov-nic-policy.yaml: done"

echo "generating ${MANIFEST_DIR}/sriov-network.yaml ..."
mkdir -p ${MANIFEST_DIR}/
envsubst < templates/sriov-network.yaml.template > ${MANIFEST_DIR}/sriov-network.yaml
sed -i "s/template-flexran-ns-name/${FLEXRAN_DU_NS}/g" ${MANIFEST_DIR}/sriov-network.yaml
echo "generating ${MANIFEST_DIR}/sriov-network.yaml: done"

##### apply sriov-nic-policy ######
#// Configuring an SR-IOV network device.
if ! oc get SriovNetworkNodePolicy policy-intel-west -n openshift-sriov-network-operator 2>/dev/null; then
    echo "create SriovNetworkNodePolicy ..."
    oc create -f ${MANIFEST_DIR}/sriov-nic-policy.yaml
    echo "create SriovNetworkNodePolicy: done"
fi

sleep 1

##### apply sriov-network ######
#// Configuring an SR-IOV ethernet network attachment
if ! oc get SriovNetwork sriov-vlan10 -n openshift-sriov-network-operator 2>/dev/null; then
    echo "create SriovNetwork ..."
    oc create -f ${MANIFEST_DIR}/sriov-network.yaml
    echo "create SriovNetwork: done"
fi

# is VF up?
if [[ "${WAIT_MCP}" == "true" ]]; then
    count=30
    printf "waiting for sriov VF come up"
    while ! exec_over_ssh ${BAREMETAL_WORKER} "ip link show ${DU_SRIOV_INTERFACE}" | egrep '^\s+vf\s'; do
        count=$((count -1))
        if ((count == 0)); then
            printf "\nSRIOV VF not coming up!\n"
            exit 1
        fi
        printf "."
        sleep 5
    done
    printf "\nSRIOV VF: up\n"
fi
