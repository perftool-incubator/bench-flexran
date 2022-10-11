#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

if [[ "${DU_FEC}" == "SW" ]]; then
    echo "using software FEC, no FEC to cleanup"
    exit 0
fi

echo "Removing FEC VF ..."
[ -e ${MANIFEST_DIR}/create-fec-vf.yaml ] && oc delete -f ${MANIFEST_DIR}/create-fec-vf.yaml
echo "Removing FEC VF: done"

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

