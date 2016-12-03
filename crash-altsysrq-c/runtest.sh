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
# Author: Qiao Zhao <qzhao@redhat.com>

# Source necessary library
. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh

C_REBOOT="./C_REBOOT"

load_altsysrq_driver()
{
    mkdir altsysrq
    cd altsysrq
    cp ../altsysrq.c .
    cp ../Makefile.altsysrq Makefile
    unset ARCH
    ( make && insmod ./altsysrq.ko )|| log_error "- make/insmod altsysrq module fail"
    export ARCH
    ARCH=$(uname -i)
    cd ..
}

crash_altsysrq_c()
{
    if [ ! -f ${C_REBOOT} ]; then
        kdump_prepare
        kdump_restart
        load_altsysrq_driver
        touch "${C_REBOOT}"
        log_info "- boot to 2nd kernel"
        echo 1 > /proc/sys/kernel/sysrq
        sync
        echo c > /proc/driver/altsysrq
        log_error "- can't arrive here!"
    else
        rm "${C_REBOOT}"
    fi

    check_vmcore_file
    ready_to_exit
}

log_info "- start"
crash_altsysrq_c
