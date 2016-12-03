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

crash_sysrq_c()
{
    # Maybe need disable avc check
    if [ ! -f "${C_REBOOT}" ]; then
        kdump_prepare
        # add config kdump.conf in here if need
        kdump_restart
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
