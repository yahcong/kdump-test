#!/usr/bin/env bash

. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh

C_REBOOT="./C_REBOOT"

crash_sysrq_c()
{
    # Maybe need disable avc check
    if [ ! -f "${C_REBOOT}" ]; then
        prepare_kdump
        # add config kdump.conf in here if need
        restart_kdump
        log_info "- boot to 2nd kernel"
        touch "${C_REBOOT}"
        sync
        echo c > /proc/sysrq-trigger
    else
        rm -f "${C_REBOOT}"
    fi

    # add check vmcore test in here if need
    check_vmcore_file
    ready_to_exit
}

log_info "- start"
crash_sysrq_c
