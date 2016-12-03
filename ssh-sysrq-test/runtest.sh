#!/usr/bin/env bash

# Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Song Qihan<qsong@redhat.com>
# Update: Qiao Zhao <qzhao@redhat.com>

# Source necessary library
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
