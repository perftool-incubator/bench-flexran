#!/bin/sh

# Install PAO and performanceprofile for SNO or reg cluster
# Usage:
#   export SNO=true  - For for SNO
#   export NSO-false - For regular cluster
#

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

# registry is not relevent to the performance operator
# but let's take care of this as early as possible
#<HN>set_registry

if [[ "${SNO}" == "false" ]]; then
  echo oc label --overwrite node ${BAREMETAL_WORKER} node-role.kubernetes.io/worker-cnf=""
fi

mkdir -p ${MANIFEST_DIR}/

##### install performnance operator #####
# skip if performance operator subscription already exists
if ! oc get Subscription performance-addon-operator -n openshift-performance-addon 2>/dev/null; then
    echo "generating ${MANIFEST_DIR}/sub-perf.yaml ..."
    export OCP_CHANNEL=$(get_ocp_channel)
    envsubst < templates/sub-perf.yaml.template > ${MANIFEST_DIR}/sub-perf.yaml
    oc create -f ${MANIFEST_DIR}/sub-perf.yaml
    echo "generating ${MANIFEST_DIR}/sub-perf.yaml: done"
fi

wait_pod_in_namespace openshift-performance-addon

###### generate performance profile ######
echo "Acquiring cpu info from worker node ${BAREMETAL_WORKER} ..."
all_cpus=$(exec_over_ssh ${BAREMETAL_WORKER} lscpu | awk '/On-line CPU/{print $NF;}')
export DU_RESERVED_CPUS=$(exec_over_ssh ${BAREMETAL_WORKER} "cat /sys/bus/cpu/devices/cpu0/topology/thread_siblings_list")

PYTHON=$(get_python_exec)
export DU_ISOLATED_CPUS=$(${PYTHON} cpu_cmd.py cpuset-substract ${all_cpus} ${DU_RESERVED_CPUS})
echo "Acquiring cpu info from worker node ${BAREMETAL_WORKER}: done"

echo "generating ${MANIFEST_DIR}/performance_profile.yaml ..."
if [[ "${SNO}" == "false" ]]; then
    export MCP=worker-cnf
else
    export MCP=master
fi
envsubst < templates/performance_profile.yaml.template > ${MANIFEST_DIR}/performance_profile.yaml
echo "generating ${MANIFEST_DIR}/performance_profile.yaml: done"

##### apply performance profile ######
if [[ "${SNO}" == "true" ]]; then
   oc label mcp master machineconfiguration.openshift.io/role=master
else
   ./create_mcp.sh
fi


echo "apply ${MANIFEST_DIR}/performance_profile.yaml ..."
oc apply -f ${MANIFEST_DIR}/performance_profile.yaml

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

echo "apply ${MANIFEST_DIR}/performance_profile.yaml: done"
