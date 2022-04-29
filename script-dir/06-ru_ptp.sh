#!/bin/sh

set -euo pipefail

source ./setting.env

print_usage() {
    declare -A arr
    arr+=( ["setup"]="setup PTP on RU"
           ["clean"]="cleanup PTP on RU"
         )
    echo "Usage:"
    echo ""
    for key in ${!arr[@]}; do
        printf '%-15s: %s\n' "$key" "${arr[$key]}"
    done
    exit 1
}

setup() {
    echo "Setting up PTP on RU ..."
    
    if ! command -v tmux >/dev/null 2>&1; then
        dnf install -y tmux
    fi
    
    if ! command -v ptp4l >/dev/null 2>&1; then
        dnf install -y linuxptp
    fi
    
    if [[ "${RU_PTP_GM_LOCAL}" == "false" ]]; then
        # if using external grand master, disable chronyd
        systemctl stop chronyd || true
        phc2sys_cmd="phc2sys -a -r -m"
    else
        # update priority1 to 127 to make local a grade master
        sed -i -r 's/^priority1(\s+)\w*/priority1\1127/' /etc/ptp4l.conf
        phc2sys_cmd="phc2sys -a -r -r -m" 
    fi
    
    ptp4l_cmd="ptp4l -f /etc/ptp4l.conf -i ${RU_PTP4L_INTERFACE} -2 -m"
    
    tmux kill-session -t ptp4l 2>/dev/null || true
    tmux new-session -s ptp4l -d "${ptp4l_cmd}"
    
    tmux kill-session -t phc 2>/dev/null || true
    tmux new-session -s phc -d "${phc2sys_cmd}"
    
    if ! tmux ls | grep ptp4l: ; then
        echo "ptp4l not working"
        exit 1
    fi
    
    if ! tmux ls | grep phc: ; then
        echo "phc not working"
        exit 1
    fi

    echo "PTP setup on RU: done"
}     


clean() {
    echo "Cleaning up PTP on RU"
    tmux kill-session -t ptp4l 2>/dev/null || true
    tmux kill-session -t phc 2>/dev/null || true
    if [[ "${RU_PTP_GM_LOCAL}" == "false" ]]; then 
        # we have stopped the chronyd for external ptp GM, restart it
        systemctl start chronyd || true
    fi
    echo "PTP cleanup on RU: done"
}


if (( $# != 1 )); then
    print_usage
else
    ACTION=$1
fi

case "${ACTION}" in
    setup)
        setup 
    ;;
    clean)
        clean 
    ;;
    *)
        print_usage
esac


