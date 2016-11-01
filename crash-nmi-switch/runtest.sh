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
# Author: Song Qihan<qsong@redhat.com>

# Source necessary library
. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh

C_REBOOT="./C_REBOOT"

crash_nmi_switch()
{
    if [[ ! -f "${C_REBOOT}" ]]; then
        prepare_kdump
        restart_kdump
        install_rpm_package "OpenIPMI" "ipmitool"
        log_info "- Load IPMI modules"
        systemctl enable ipmi
        systemctl start ipmi || service ipmi start || log_error "Failed to start ipmi service"
    
        echo 1 > /proc/sys/kernel/panic_on_unrecovered_nmi
        touch "${C_REBOOT}"
        sync
        ipmitool chassis power diag
        log_error "Can not trigger IPMI crash"
    else
        rm -f "${C_REBOOT}"
    fi

    check_vmcore_file
    ready_to_exit
}

log_info "- start"
crash_nmi_switch
