#!/bin/sh

set -euo pipefail

source ./setting.env
source ./functions.sh

parse_args $@

echo "Removing PtpConfig ..."
[ -e ${MANIFEST_DIR}/ptp-config.yaml ] && oc delete -f ${MANIFEST_DIR}/ptp-config.yaml || true
echo "Removing PtpConfig: done"

# Uncomment the next line when debug ptp to avoid chronyd op. It reboots the node.
# echo HN short circuit: no renable chronyd; exit
echo "Restore chronyd.service ..."
[ -e ${MANIFEST_DIR}/disable-chronyd.yaml ] && oc delete -f ${MANIFEST_DIR}/disable-chronyd.yaml

if [[ "${WAIT_MCP}" == "true" ]]; then
    wait_mcp
fi

echo "Restore chronyd.service: done"

