#!/usr/bin/env bash

. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh


C_REBOOT="./C_REBOOT"

ssh_sysrq_test()
{

    # Check parameter
    if [[ ! -z "$1" ]]; then
        ${SERVERS:=$1}
    fi 
    if [[ ! -z "$2" ]]; then
        ${CLIENTS:=$2}
    fi
    if [ -z "${SERVERS}" -o -z "${CLIENTS}" ]; then
        log_error "Unknow Server or Client hostname or address"
    fi
    export SERVERS=${SERVERS}
    export CLIENTS=${CLIENTS}

    if [[ ! -f "${C_REBOOT}" ]]; then
        kdump_prepare
        prepare_for_multihost
        config_ssh 
        kdump_restart
        if [[ $(get_role) == "client" ]]; then
            log_info "Client boot to 2nd kernel" 
            touch "${C_REBOOT}"
            sync
            echo c > /proc/sysrq-trigger
            # Stop here
        fi 

        if [[ $(get_role) == "server" ]]; then
            trigger_wait_at_server 
            check_vmcore_file
        fi
    else
        rm -f "${C_REBOOT}"
        trigger_notify_at_client "${SERVERS}"
        log_info " Client successful crashed" 
    fi
    ready_to_exit
}

log_info "- start"
ssh_sysrq_test "$@"
