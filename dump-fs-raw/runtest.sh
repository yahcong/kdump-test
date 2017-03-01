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
# Author: Yahuan Cong<ycong@redhat.com>

# Source necessary library
. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh
dump_fs_raw()
{
    # May need disable avc check
    if [ ! -f "${C_REBOOT}" ]; then
        kdump_prepare

        append_config "core_collector makedumpfile -F -d 31"
        kdump_restart

        MP="/raw" RAW="yes"
        config_kdump_target
        report_system_info

        trigger_sysrq_crash
    else
        rm -f "${C_REBOOT}"

        # add check vmcore test in here if need
        validate_vmcore_exists
    fi
    ready_to_exit
}

log_info "- Start"
dump_fs_raw
