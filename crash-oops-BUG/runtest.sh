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

crash_oops_BUG()
{
    if [[ ! -f "${C_REBOOT}" ]]; then
        kdump_prepare
        kdump_restart
        report_system_info
        make_module "oops_BUG"
        insmod oops_BUG/oops_BUG.ko || log_error "- Failed to insmod module."

        touch "${C_REBOOT}"
        sync;sync;sync
        log_info "- Triggering crash."
        # workaround for bug 810201
        echo 1 > /proc/sys/kernel/panic_on_opps
        sync;sync;sync
        echo 1 > /proc/crasher

        # Wait for a while
        sleep 60
        log_error "- Failed to trigger oops_BUG after waiting for 60s."
    else
        rm -f "${C_REBOOT}"
    fi
    ready_to_exit
}

log_info "- Start"
crash_oops_BUG
