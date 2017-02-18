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

crash_nmi_switch()
{
    if [[ ! -f "${C_REBOOT}" ]]; then
        kdump_prepare
        kdump_restart
        report_system_info
        install_rpm_package "OpenIPMI" "ipmitool"
        log_info "- Load IPMI modules"
        systemctl enable ipmi
        systemctl start ipmi || service ipmi start || log_error "- Failed to start ipmi service."

        echo 1 > /proc/sys/kernel/panic_on_unrecovered_nmi
        touch "${C_REBOOT}"
        log_info "- Triggering crash."
        sync;sync;sync
        ipmitool chassis power diag

        # Wait for a while
        sleep 60
        log_error "- Failed to trigger IPMI crash after waiting for 60s."
    else
        rm -f "${C_REBOOT}"
        validate_vmcore_exists
    fi
    ready_to_exit
}

log_info "- Start"
crash_nmi_switch
