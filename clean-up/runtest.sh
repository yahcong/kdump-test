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
    if [ -f "${K_PATH}" ]; then
        local path=$(cat "${K_PATH}")
        if [ -d "${path}" ]; then
            log_info "- Removing vmcore files in ${path}."
            rm -rf "${path}"/*
        fi
    elif [ -d "${K_DEFAULT_PATH}" ]; then
        log_info "- Removing vmcore files in default path ${K_DEFAULT_PATH}"
        rm -rf "${K_DEFAULT_PATH}"/*
    fi

    if [ $? -eq 0 ]; then
        log_info "- Vmcore files have been deleted successfully."
    else
        log_error "- Failed to delete vmcore files."
    fi

    log_info "- Restoring firewall status."

    log_info "- Restoring iptables/ip6tables rules."

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

    log_info "- Restoring firewall-cmd rules."

    for iport in $(ls ${K_FIREWALLD_PREFIX}_tcp_*); do
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/tcp --permanent
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/tcp
    done

    for iport in $(ls ${K_FIREWALLD_PREFIX}_udp_*); do
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/udp --permanent
        firewall-cmd --remove-port=$(echo $iport| awk -F '_' '{print $3}')/udp
    done

    for iservice in $(ls ${K_FIREWALLD_PREFIX}_service_*); do
        firewall-cmd --remove-service=$(echo $iservice| awk -F '_' '{print $3}') --permanent
        firewall-cmd --remove-service=$(echo $iservice| awk -F '_' '{print $3}')
    done

    # Restore sshd status
    if [ -f ${K_SSHD_ENABLE} ]; then
        log_info "- Restoring sshd status."
        systemctl disable sshd || chkconfig sshd off

        if [ $? -eq 0 ]; then
            log_info "- SSHD service has been turned off successfully."
        else
            log_error "- Failed to turn off sshd service."
        fi
    fi

    log_info "- Removing all temporary files."
    rm -f "${K_PATH}" "${K_RAW}" "${K_REBOOT}"
    rm -rf "${K_INFO_DIR}"

    log_info "- Restoring kdump.conf file."
    cp -f "${K_BACKUP_DIR}"/kdump.conf /etc/kdump.conf

    log_info "- Clean up is done."
    ready_to_exit
}

log_info "- Start"
clean_up
