#!/usr/bin/env bash

# Copyright (c) 2016 Red Hat, Inc. All rights reserved. This copyrighted material
# is made available to anyone wishing to use, modify, copy, or
# redistribute it subject to the terms and conditions of the GNU General
# Public License v.2.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Xiaowu Wu<xiawu@redhat.com>

# library
. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh

C_REBOOT="./C_REBOOT"

crash-oops-warn()
{
    if [[ ! -f "${C_REBOOT}" ]]; then
        kdump_prepare
        kdump_restart
        report_system_info
        log_info "making and installing crash-warn.ko"
        make_module "crash-warn"

        # Set panic_on_warn
        log_info "- # echo 1 > /proc/sys/kernel/panic_on_warn."
        echo 1 > /proc/sys/kernel/panic_on_warn
        if [[ $? -ne 0 ]]; then
            log_error "Error to echo 1 > /proc/sys/kernel/panic_on_warn"
        fi

        # Trigger panic_on_warn
        touch "${C_REBOOT}"
        sync
        log_info "- Triggering crash."
        insmod crash-warn/crash-warn.ko || log_error "Failed to insmod module."
        if [ $? -ne 0 ]; then
            log_error "Fail to trigger panic_on_warn"
        fi

        # Wait for a while
        sleep 3600
        log_error "- Failed to trigger panic_on_warn after waiting for 3600s."

    else
        rm -f "${C_REBOOT}"
    fi

    # validate vmcore
    check_vmcore_file
    ready_to_exit
}

log_info "- Start"
crash-oops-warn
