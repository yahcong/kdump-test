#!/usr/bin/env bash

# Basic Library for Kdump Multi-Host Test

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
# Author: Qiao Zhao <qzhao@redhat.com>

. ../lib/log.sh
. ../lib/kdump.sh


# @usage: get_role
# @description: get role for current host
# @return: server/client
get_role()
{
    if [[ "${SERVERS}" == "${HOSTNAME}" ]]; then
        echo "server"; return
    elif [[ "${CLIENTS}" == "${HOSTNAME}" ]]; then
        echo "client"; return
    fi

    if [[ ipcalc -c "${SERVERS}" ]] && [[ is_host_ip "${SERVERS}" ]]; then
        echo "server"; return
    elif [[ ipcalc -c "${CLIENTS}" ]] && [[ is_host_ip "${CLIENTS}" ]]; then
        echo "client"; return
    fi

    log_error "- Unable to determine host role."
}


# @usage: is_host_ip <ip>
# @description: check if host ip matches the ip passed in
# @param1: ip
# @return: 0 - matches / 1 - not match
is_host_ip()
{
    for ip in $(ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
        [[ $ip == "$1" ]] && return 0
    done
    return 1
}


# @usage: open_firewall_service <fw_service>
# @description:
#       open a service on firewall using firewall-cmd
#       skip the step if no firewalld is running.
# @param1: fw_service
open_firewall_service()
{
    [ $# -lt 1 ] && log_error "- Syntax error: Expecting a service name."

    local fw_service=$1

    log_info "- Opening service ${fw_service} on firewall"
    systemctl status firewalld
    if [ $? -ne 0 ]; then
            firewall-cmd --list-service | grep "${fw_service}"
            if [ $? -ne 0 ]; then
                touch "${K_PREFIX_FWD}_service_${fw_service}"
                firewall-cmd --add-service=${fw_service}
                firewall-cmd --add-service=${fw_service} --permanent
            fi
    else
        log_info "- Skipped. The iptables service is not running."
    fi
}


# @usage: open_firewall_service <fw_protocol> <fw_port>
# @description:
#       open a port on firewall using firewall-cmd or iptables
#       skip the step if o firewalld or iptables is running.
# @param1: fw_protocol
# @param2: fw_port
open_firewall_port()
{
    [ $# -lt 2 ] && log_error "- Syntax error: Expecting a protocol and port"

    local fw_protocol=$1
    local fw_port=$2

    log_info "- Opening port ${fw_port}/${fw_protocol} on firewall"
    local mode=off
    service iptables status && mode=iptables
    systemctl status firewalld && mode=firewalld

    case $mode in
        firewalld)
            firewall-cmd --list-ports | grep "${fw_port}/${fw_protocol}"
            if [ $? -eq 0 ]; then
                touch "${K_PREFIX_FWD}_${fw_protocol}_${fw_port}"
                firewall-cmd --add-port=${fw_port}/${fw_protocol}
                firewall-cmd --add-port=${fw_port}/${fw_protocol} --permanent
            fi
            ;;
        iptables)
            iptables-save | grep -i "${fw_protocol}" | grep "${fw_port}"
            if [ $? -ne 0 ]; then
                touch "${K_PREFIX_IPT}_${fw_protocol}_${fw_port}"
                iptables -I INPUT -p ${fw_protocol} --dport ${fw_port} -j ACCEPT
                service iptables save
                ip6tables -I INPUT -p ${fw_protocol} --dport ${fw_port} -j ACCEPT
                service ip6tables save
            fi
            ;;
        off)
            log_info "- Skipped .The firewalld or iptables service is not running."
            ;;
    esac
}


# @usage: wait_for_signal <port>
# @description:
#       wait for signal at given port.
#       used for client/server sync
# @param1: port
wait_for_signal()
{
    open_firewall_port tcp $1
    nc -l $1
    if [ $? -ne 0 ]; then
        log_error "- Got error listening for signal at port $1"d
    else
        log_info "- Received signal at port $1"
    fi
}


# @usage: send_notify_signal <hostname|ip><port>
# @description:
#       send signal to server <hostname|ip> at <port>
#       used for client/server sync
# @param1: hostname or ip
# @param1: port
send_notify_signal()
{
    local server=$1
    local port=$2

    local count=${K_RETRY_COUNT}
    local result=1

    # try dump message to /dev/tcp/${server}/${port}
    while [ $count -gt 0 ]; do
        echo "Success" > "/dev/tcp/${server}/${port}"
        if [ $? -eq 0 ]; then
            result=0
            break
        else
            sleep 10s
        fi
        (( count = count - 1 ))
    done

    if [ ${result} -eq 1 ]; then
        log_error "- Failed to notify server, got timeout."
    else
        log_info "- Sent notify signal to ${server} at ${port} successfully"
    fi
}


# @usage: config_ssh <hostname|ip><port>
# @description:
#       config ssh for kdump on server/client
#       applicable for both ipv4 and ipv6
#       including,
#           set up ssh connection without passwd between s/c
#           config kdump.conf on client for ssh dump
# @param1: $1   # v4 or v6. default to 'v4'
config_ssh()
{
    install_rpm openssh-server openssh-clients
    local server=${SERVERS}
    local client=${CLIENTS}

    # Path where server will save its ipv6 addr to and where client will fetch
    local path_ipv6_addr="/root/server-ipv6-address"

    ip_version=${1:-"v4"}
    if [ "${ip_version}" != "v4" -a "${ip_version}" != "v6" ]; then
        log_error "- ${ip_version} is not supported. Onlyl ipv4 or ipv6 is supported."
    fi

    # port used for client/server sync
    local sync_port=35412

    if [[ $(get_role) == "client" ]]; then  # copy keys
        ## Note that if client exit with error during configuration
        ## It must notify server that config is done at client before exiting
        ## Otherwise server will wait for the client in order to
        ## proceed to next step to check vmcore file.

        log_info "- Preparing ssh authentication at client"

        mkdir -p "${K_LOCK_AREA}/.ssh"
        cp ../lib/id_rsa ${K_LOCK_SSH_ID_RSA}
        chmod 0600 ${K_LOCK_SSH_ID_RSA}
        cp ../lib/id_rsa.pub "${K_LOCK_SSH_ID_RSA}.pub"
        chmod 0600 "${K_LOCK_SSH_ID_RSA}.pub"

        # turn off StrictHostKeyChecking
        [[ -f ${K_SSH_CONFIG} ]] && sed -i "/^StrictHostKeyChecking/d" "${K_SSH_CONFIG}"
        echo "StrictHostKeyChecking no" >> "${K_SSH_CONFIG}"

        log_info "- Waiting for signal from server that sshd service is ready at server."
        wait_for_signal ${sync_port}


        # Test ssh connection
        log_info "- Test ssh connection between c/s."
        ssh -o StrictHostKeyChecking=no -i ${K_LOCK_SSH_ID_RSA} "${server}" 'touch ${K_LOCK_AREA}/ssh_test'

        if [ $? -ne 0 ]; then
            log_info "- Notifying server that configuration is done at client"
            send_notify_signal "${server}" "${sync_port}"
            log_error "- SSH connection test failed."
        fi
        log_info "- SSH connection test passed."

        # update kdump config file for dumping via ssh
        if [[ ${ip_version} == "v6" ]]; then
            # get server ipv6 address
            ssh -i ${K_LOCK_SSH_ID_RSA} "${server}" "cat ${path_ipv6_addr}" > ${path_ipv6_addr}.out
            [ $? -eq 0 ] || log_error "- Failed to get server ipv6 address."
            server_ipv6=$(grep -P '^[0-9]+' ${path_ipv6_addr}.out | head -1)
            config_kdump_any "ssh root@${server_ipv6}"
        else
            config_kdump_any "ssh root@${server}"
        fi
        config_kdump_any "path ${K_DEFAULT_PATH}"
        config_kdump_any "sshkey ${K_LOCK_SSH_ID_RSA}"
        config_kdump_filter

        if [[ "${K_DIST_VER}" == "6" ]]; then
            # Only required for RHEL6.
            # It needs to wait for while for network readyness
            config_kdump_any "link_delay 60"
        fi
        log_info "- Updated Kdump config file for ssh kdump."

        log_info "- Notifying server that ssh/kdump config is done at client."
        send_notify_signal "${server}" "${sync_port}"

    elif [[ $(get_role) == "server" ]]; then
        log_info "- Preparing ssh authentication at server"

        systemctl status sshd || service sshd status
        if [ $? -ne 0 ]; then
            systemctl start sshd || service sshd start
            touch "${K_PREFIX_SSH}"
            systemctl enable sshd || chkconfig sshd on
            open_firewall_port tcp 22
        fi
        mkdir -p "/root/.ssh"
        touch "/root/.ssh/authorized_keys"
        cat ../lib/id_rsa.pub >> "/root/.ssh/authorized_keys"
        restorecon -R "/root/.ssh/authorized_keys"

        # save server ipv6 address to ${path_ipv6_addr}
        if [ "${ip_version}" == "v6" ]; then
            ifconfig | grep inet6\ | grep global | awk -F' ' '{print $2}' > ${path_ipv6_addr}
            if [ $? -eq 0 ]; then
                log_info "- Sending signal to client that server is done with error."
                send_notify_signal  "${client}"  "${sync_port}"
                log_error "- Failed to get ipv6 address from Server"
            fi
        fi

        systemctl restart sshd || service sshd restart || log_error "- Failed to restart sshd"

        # notify client that ssh config and service is ready at server
        log_info "- Sending signal to client that ssh config/service is ready at server"
        send_notify_signal "${client}" "${sync_port}"

        log_info "- Waiting signal from client that client's configuration is done"
        wait_for_signal ${sync_port}
        return
    else
        log_error "- Can not determine the role of host."
    fi
}


# @usage: config_nfs
# @description:
#       config nfs service on server/client
#       config kdump.config for nfs dump
#       NOT DONE YET! DON'T USE
config_nfs()
{
    log_info "- configuring nfs target"
    rpm -q nfs-utils
    if [ $? -ne 0 ]; then
        log_error "- Error: nfs not installed. Exiting"
    fi
    if [[ ${K_DIST_NAME} == "el" ]] && [ ${K_DIST_VER} -lt 7 ]; then
        log_warn "- Warning: You need to manually configure iptables rules for NFS on RHEL 6."
        open_firewall_port tcp 2049
        open_firewall_port udp 2049
        open_firewall_port tcp 111
        open_firewall_port udp 111
    else
        open_firewall_service mountd
        open_firewall_service rpc-bind
        open_firewall_service nfs
    fi
    # TODO: Add kdump configuration for NFS server.
}