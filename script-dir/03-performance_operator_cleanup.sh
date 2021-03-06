#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

echo "Removing performance profile ..."
[ -e ${MANIFEST_DIR}/performance_profile.yaml ] && oc delete -f ${MANIFEST_DIR}/performance_profile.yaml

if [[ "${SNO}" == "true" ]]; then
   oc label mcp master machineconfiguration.openshift.io/role-
fi

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

echo "Removing performance profile: done"
