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
# Update: Ziqian SUN <zsun@redhat.com>


. ../lib/kdump.sh
. ../lib/log.sh

clean_up()
{
    if [ -d "${KPATH}" ]; then
        log_info "- Remove all vmcore* file in ${KPATH}"
        rm -rf "${KPATH}"/*
    else
        log_info "- Remove all vmcore* file in ${K_DEFAULT_PATH}"
        rm -rf "${K_DEFAULT_PATH}"/*
    fi

    log_info "- Restore firewall status."
    for iport in $(ls ${K_IPTABLES_PREFIX}_tcp_*); do
        iptables -D INPUT -p tcp --dport $(echo $iport| awk -F '_' '{print $3}')
        ip6tables -D INPUT -p tcp --dport $(echo $iport| awk -F '_' '{print $3}')
        service iptables save
        service ip6tables save
    done
    for iport in $(ls ${K_IPTABLES_PREFIX}_udp_*); do
        iptables -D INPUT -p udp --dport $(echo $iport| awk -F '_' '{print $3}')
        ip6tables -D INPUT -p udp --dport $(echo $iport| awk -F '_' '{print $3}')
        service iptables save
        service ip6tables save
    done
    for iport in $(ls ${K_FIREWALLD_PREFIX}_tcp_*); do
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/tcp --permanent
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/tcp
    done
    for iport in $(ls ${K_FIREWALLD_PREFIX}_udp_*); do
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/udp --permanent
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/udp
    done

    # Restore sshd status
    log_info "- Restore sshd status."
    if [ -f ${K_SSHD_ENABLE} ]; then
        systemctl disable sshd || chkconfig sshd off
    fi


    log_info "- Remove all temporary files."
    rm -f ../lib/"${K_REBOOT}"
    rm -rf ${K_INFO_DIR}

    log_info "- Revert kdump.conf file."
    cp -f ../lib/"${K_BACKUP_DIR}"/kdump.conf /etc/kdump.conf

    log_info "- Clean up end."
}

log_info "- Start"
clean_up
