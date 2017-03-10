#!/usr/bin/env bash

# Basic Library for Reporting System Status

# Copyright (C) 2016 Song Qihan <qsong@redhat.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Ziqian Sun <zsun@redhat.com>

. ../lib/log.sh
. ../lib/kdump.sh

# @description: report hardware info
report_hw_info()
{
    echo -e "Architecture:" >> "${K_HWINFO_FILE}"
    arch >> "${K_HWINFO_FILE}"

    echo -e "\n----\n"      >> "${K_HWINFO_FILE}"
    echo -e "CPU Info:"     >> "${K_HWINFO_FILE}"
    lscpu >> "${K_HWINFO_FILE}"

    echo -e "\n----\n"      >> "${K_HWINFO_FILE}"
    echo -e "Memory Info:"  >> "${K_HWINFO_FILE}"
    free -h >> "${K_HWINFO_FILE}"

    echo -e "\n----\n"      >> "${K_HWINFO_FILE}"
    echo -e "Storage Info:" >> "${K_HWINFO_FILE}"
    lsblk >> "${K_HWINFO_FILE}"

    echo -e "\n----\n"      >> "${K_HWINFO_FILE}"
    echo -e "Network Info:" >> "${K_HWINFO_FILE}"
    ip link >> "${K_HWINFO_FILE}"
    for i in $(ip addr | grep -i ': <' | grep -v 'lo:' | awk '{print $2}' | sed "s/://g") ; do
        echo "--$i--" >> "${K_HWINFO_FILE}"
        ethtool -i $i >> "${K_HWINFO_FILE}"
    done

    report_file "${K_HWINFO_FILE}"
}


# @description: report file list in initrd*kdump.img
report_lsinitrd()
{
    INITRAMFS_SUFFIX="$(uname -r)kdump.img"
    INITRAMFS_NAME=$(ls /boot | grep "${INITRAMFS_SUFFIX}")
    lsinitrd "/boot/${INITRAMFS_NAME}" >> "${K_INITRAMFS_LIST}"
    report_file "${K_INITRAMFS_LIST}"
}


# @usage: report_system_info
# @description: report system info inclufing hw/initrd/kdump.config
report_system_info()
{
    log_info "- Reporting system info."
    report_hw_info
    report_lsinitrd
    report_file "${K_CONFIG}"
}
