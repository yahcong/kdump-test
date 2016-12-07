#!/usr/bin/env bash

((LIB_KDUMP_SH)) && return || LIB_KDUMP_SH=1
. ../lib/log.sh

K_ARCH="$(uname -m)"
K_REBOOT="./K_REBOOT"
K_PATH="./KDUMP-PATH"
K_RAW="./KDUMP-RAW"
K_BACKUP_DIR="./backup"

K_CONFIG="/etc/kdump.conf"
K_DEFAULT_PATH="/var/crash"
K_SSH_CONFIG="${HOME}/.ssh/config"

readonly K_LOCK_AREA="/root"
readonly K_LOCK_SSH_ID_RSA=/root/.ssh/id_rsa_kdump_test
readonly K_RETRY_COUNT=1000

KPATH=${KPATH:-${K_DEFAULT_PATH}}
OPTION=${OPTION:-}
MP=${MP:-/}
LABEL=${LABEL:-label-kdump}
RAW=${RAW:-no}


install_rpm_package()
{
    if [[ $# -gt 0 ]];then
        yum install -y "$@" || log_error "- Can not install rpm: $*"
        log_info "- Installed $* successfully"
    fi
}

# Backup kdump.conf
prepare_env()
{
    mkdir -p "${K_BACKUP_DIR}"
    cp /etc/kdump.conf "${K_BACKUP_DIR}"/
}

# Prepare for kdump service
# Including:
#   Update kernel cmdline for kernel memory and default vmlinuz(x)
#   Set KDUMP_IMG in /etc/sysconfig/kdump
#   Install kexec-tools
#   Enable kdump service
kdump_prepare()
{
    if [ ! -f "${K_REBOOT}" ]; then
        prepare_env
        local default
        default=/boot/vmlinuz-$(uname -r)
        [ ! -s "$default" ] && default=/boot/vmlinux-$(uname -r)
        /sbin/grubby --set-default="${default}"

        # for uncompressed kernel, i.e. vmlinux
        [[ "${default}" == *vmlinux* ]] && {
            log_info "- Modifying /etc/sysconfig/kdump properly for 'vmlinux'."
            sed -i 's/\(KDUMP_IMG\)=.*/\1=vmlinux/' /etc/sysconfig/kdump
        }

        # In Fedora and upstream kernel, crashkernel=auto is not suppored.
        # By checking if /sys/kernel/kexec_crash_size is zero, we can tell if
        # auto crashkernel is supported and if crash memory is allocated.

        # If it is not supported, we need to specify the memory by changing
        # kernel param to crashkernel=<>M, and reboot system.

        grep -q 'crashkernel' <<< "${KERARGS}" || {
                [ "$(cat /sys/kernel/kexec_crash_size)" -eq 0 ] && {
                    log_info "- MemTotal is:" "$(grep MemTotal /proc/meminfo)"
                    KERARGS+="$(def_kdump_mem)"
                }
        }

        [ "${KERARGS}" ] && {
            # touch a file to mark system's been rebooted for kernel cmdline chagne.
            touch ${K_REBOOT}
            log_info "- Changing boot loader."
            {
                /sbin/grubby    \
                    --args="${KERARGS}"    \
                    --update-kernel="${default}" &&
                if [ "${K_ARCH}" = "s390x" ]; then zipl; fi
            } || {
                log_error "- Change boot loader error!"
            }
            log_info "- Reboot system for system preparing."
            reboot_system
        }

    fi

    # install kexec-tools package
    rpm -q kexec-tools || install_rpm_package kexec-tools

    # enable kdump service: systemd | sys-v
    /bin/systemctl enable kdump.service || /sbin/chkconfig kdump on || log_error "- Failed to enable kdump!"
    log_info "- Enabled kdump service"
}

# Restart kdump service
kdump_restart()
{
    log_info "- Restart kdump service."
    # delete kdump.img in /boot directory
    rm -f /boot/initrd-*kdump.img || rm -f /boot/initramfs-*kdump.img
    touch "${K_CONFIG}"
    /usr/bin/kdumpctl restart 2>&1 || /sbin/service kdump restart 2>&1 || log_error "- Failed to start kdump!"
    log_info "- Kdump service starts successfully."
}

# Config default kdump memory
def_kdump_mem()
{
    local args=""

    case "${K_ARCH}" in
        "x86_64")
            args="crashkernel=160M"
            ;;
        "ppc64")
            args="crashkernel=320M"
            ;;
        "ppc64le")
            args="crashkernel=320M"
            ;;
        "s390x")
            args="crashkernel=160M"
            ;;
        "aarch64")
            args="crashkernel=2048M"
            ;;
        *)
            ;;
    esac

    echo "$args"
}


# Append one option to kdump.conf
append_config()
{
    log_info "- Modifying /etc/kdump.conf"
    if [ $# -eq 0 ]; then
        log_info "- Nothing to modify."
        return 0
    fi

    while [ $# -gt 0 ]; do
        log_info "- Removing existing ${1%%[[:space:]]*} settings."
        sed -i "/^${1%%[[:space:]]*}/d" ${K_CONFIG}
        log_info "- Adding new config '$1'."
        echo "$1" >> "${K_CONFIG}"
        shift
    done

    log_info "- Dump kdump.conf file."
    log_info $(grep -v ^# "${K_CONFIG}")
}

# Label a parition
label_fs()
{
    local fstype="$1"
    local dev="$2"
    local mp="$3"
    local label=$4

    case $fstype in
        xfs)
            umount $dev &&
            xfs_admin -L $label $dev &&
            mount $dev $mp
            ;;
        ext[234])
            e2label $dev $label
            ;;
        btrfs)
            umount $dev &&
            btrfs filesystem label $dev $label &&
            mount $dev $mp
            ;;
        *)
            false
            ;;
    esac

    if [ $? -ne 0 ]; then
        log_err "- Failed to label $fstype with $label on $dev"
    fi
}

# Config kdump.conf
# Not done yet
configure_kdump_conf()
{
    # To Do:
    # Allow parameters like:
    # config_raw, config_dev_name, config_dev_uuid, config_dev_label
    # config_nfs, config_ssh, config_ssh_key
    # config_path
    # config_core_collector
    # config_post, config_pre
    # config_extra
    # config_default
    log_info "- config kdump configuration"
    local dev=""
    local fstype=""
    local target=""

    # get dev, fstype
    if [ "yes" == "$RAW" -a -f "${K_RAW}" ]; then
        dev=$(cut -d" " -f1 ${K_RAW})
        fstype=(cut -d" " -f2 ${K_RAW})
        rm -f ${K_RAW}
        mkfs."${fstype[0]}" "$dev" && mount "$dev" "$MP"
    else
        dev=$(findmnt -kcno SOURCE "$MP")
        fstype=$(findmnt -kcno FSTYPE "$MP")
    fi

    case $OPTION in
        uuid)
            # some partitions have both UUID= and PARTUUID=, we only want UUID=
            target=$(blkid "$dev" -o export -c /dev/null | grep '\<UUID=')
            ;;
        label)
            target=$(blkid "$dev" -o export -c /dev/null | grep LABEL=)
            if [ -z "$target" ]; then
                label_fs "$fstype" "$dev" "$MP" "$LABEL"
                target=$(blkid "$dev" -o export -c /dev/null | grep LABEL=)
            fi
            ;;
        softlink)
            ln -s "$dev" "$dev-softlink"
            target=$dev-softlink
            ;;
        *)
            target=$dev
            ;;
    esac

    if [ "yes" == "$RAW" -a -n "$target" ]; then
        append_config "raw $target"
        sed -i "/[ \t]\\$MP[ \t]/d" /etc/fstab
        echo "$dev $fstype" > ${K_RAW}
    elif [ -n "$fstype" -a -n "$target" ]; then
        append_config "$fstype $target" "path $KPATH"
        mkdir -p "$MP/$KPATH"
        # tell crash analyse procedure where to find vmcore
        echo "${MP%/}${KPATH}" > ${K_PATH}
    else
        log_error "- Null dump_device/uuid/label or wrong type."
    fi
}

make_module()
{
    local name
    name=$1
    if [[ -z "${name}" ]];then
        log_error "- No module name is provided."
    fi
    mkdir "${name}"
    cp "${name}".c "${name}/"
    cp Makefile."${name}" "${name}/Makefile"

    unset ARCH

    make -C "${name}/" || log_error "- Can not make module."
    export ARCH
    ARCH=$(uname -m)
}


# Prepare for client/server communication
# Install nc client
prepare_for_multihost()
{
    which nc || yum install -y nmap-ncat || yum install -y nc || log_error "- Failed to install nc client"
}


# Config ssh on server/client
# Applicable for both ipv4 and ipv6
# Including:
#   set up ssh connection without passwd between s/c
#   config kdump.conf on client for ssh dump
# Param:
#   $1 - v4 or v6 (v4 if $1 is not given)
config_ssh()
{
    install_rpm_package openssh-server openssh-clients
    local server
    server=${SERVERS}
    local client
    client=${CLIENTS}

    # Path where server will save its ipv6 addr to and where client will fetch
    local path_ipv6_addr="/root/server-ipv6-address"

    ip_version=${1:-"v4"}
    if [ ${ip_version} != "v4" -a ${ip_version} != "v6" ]; then
        log_error "- ${ip_version} is not supported. Onlyl ipv4 or ipv6 is supported."
    fi

    # port used for client/server sync
    local sync_port
    sync_port=35412

    if [[ $(get_role) == "client" ]]; then  # copy keys
        ## Note that if client exit with error during configuration
        ## It must notify server that config is done at client before exiting
        ## Otherwise server will keep waiting for the client in order to
        ## proceed to next step to check vmcore file.

        log_info "- Preparing ssh authentication at client"

        mkdir -p "/root/.ssh"
        cp ../lib/id_rsa ${K_LOCK_SSH_ID_RSA}
        chmod 0600 ${K_LOCK_SSH_ID_RSA}
        cp ../lib/id_rsa.pub "${K_LOCK_SSH_ID_RSA}.pub"
        chmod 0600 "${K_LOCK_SSH_ID_RSA}.pub"

        # turn off StrictHostKeyChecking
        if [[ -f ${K_SSH_CONFIG} ]]; then
            sed -i "/^StrictHostKeyChecking/d" ${K_SSH_CONFIG}
        fi
        echo "StrictHostKeyChecking no" >> ${K_SSH_CONFIG}

        log_info "- Waiting for signal from server that sshd service is ready at server."
        wait_for_signal ${sync_port}


        # Test ssh connection
        log_info "- Test ssh connection between c/s."
        ssh -o StrictHostKeyChecking=no -i ${K_LOCK_SSH_ID_RSA} "${server}" 'touch ${K_LOCK_AREA}/ssh_test' 
        # ssh -o StrictHostKeyChecking=no -i ${K_LOCK_SSH_ID_RSA} "${server}" 'touch ${K_LOCK_AREA}/ssh_test' 
        if [ $? -ne 0 ]; then
            log_info "- Notifying server that configuration is done at client"
            send_notify_signal ${server} ${sync_port}  
            log_error "- SSH connection test failed."
        fi
        log_info "- SSH connection test passed."

        # update kdump config file for dumping via ssh
        if [[ ${ip_version} == "v6" ]]; then
            # get server ipv6 address
            ssh -i ${K_LOCK_SSH_ID_RSA} "${server}" "cat ${path_ipv6_addr}" > ${path_ipv6_addr}.out
            [ $? -eq 0 ] || log_error "- Failed to get server ipv6 address."
            server_ipv6=$(grep -P '^[0-9]+' ${path_ipv6_addr}.out | head -1)
            append_config "ssh root@${server_ipv6}"
        else
            append_config "ssh root@${server}"
        fi
        append_config "path ${K_DEFAULT_PATH}"
        append_config "sshkey ${K_LOCK_SSH_ID_RSA}"
        append_config "core_collector makedumpfile -l -F --message-level 1 -d 31"
        if [[ "$(grep -o '[0-9.]\+' /etc/redhat-release)" =~ ^6 ]]; then
            # Only required for RHEL6.
            # It needs to wait for while for network readyness
            append_config "link_delay 60"
        fi
        log_info "- Updated Kdump config file for ssh kdump."
        
        log_info "- Notifying server that ssh/kdump config is done at client."
        send_notify_signal ${server} ${sync_port}   


    elif [[ $(get_role) == "server" ]]; then
        log_info "- Preparing ssh authentication at server"

        mkdir -p "/root/.ssh"
        touch "/root/.ssh/authorized_keys"
        cat ../lib/id_rsa.pub >> "/root/.ssh/authorized_keys"
        restorecon -R "/root/.ssh/authorized_keys"

        # save server ipv6 address to ${path_ipv6_addr}
        if [ ${ip_version} == "v6" ]; then
            ifconfig | grep inet6\ | grep global | awk -F' ' '{print $2}' > ${path_ipv6_addr}
            if [ $? -eq 0 ]; then
                log_info "- Sending signal to client that server is done with error."
                send_notify_signal  ${client}  ${sync_port}
                log_error "- Failed to get ipv6 address from Server"
            fi
        fi

        systemctl restart sshd || service sshd restart || log_error "Failed to restart sshd"

        # notify client that ssh config and service is ready at server
        log_info "- Sending signal to client that ssh config/service is ready at server"
        send_notify_signal ${client} ${sync_port}

        log_info "- Waiting signal from client that client's configuration is done"
        wait_for_signal ${sync_port}
        return
    else
        log_error "- Can not determine the role of host."
    fi
}


# Wait for signal at given port
# Used for client/server sync
wait_for_signal()
{
    local port=$1
    nc -l ${port}
    if [ $? -ne 0 ]; then
        log_info "- Get error listening for signal at port ${port}"
        return 1
    else
        log_info "- Received signal at port ${port}"
    fi
}

# Send notify signal
# Used for client/server sync
# Param:
# $1 - hostname or ip
# $2 - port
send_notify_signal()
{
    local count
    count=${K_RETRY_COUNT}
    local result
    result=1

    local server=$1
    local port=$2

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


# Get role of current host (client/server)
# Used for multi-host task
# Param:
# Global:
#   SERVERS - server ip or hostname
#   CLIENTS - client ip or hostname
# Return:
#   server/client
get_role()
{
    if ipcalc -c "${SERVERS}" &> /dev/null; then
        if is_ip_match_host "${SERVERS}"; then
            echo "server"
            return
        fi
    else
        if [[ "${SERVERS}" == "${HOSTNAME}" ]]; then
            echo "server";return
        fi
    fi

    if ipcalc -c "${CLIENTS}" &> /dev/null; then
        if is_ip_match_host "${CLIENTS}"; then
            echo "client"
            return
        fi
    else
        if [[ "${CLIENTS}" == "${HOSTNAME}" ]]; then
            echo "client"
            return
        fi
    fi

    log_error "- Unable to determine roles."
}


# Check if host ip matches the ip passed in
# Param:
#   1 - an ip
# Return:
#   0 - ip matches
#   1 - ip doesn't match
is_ip_match_host()
{
    local input_ip=$1
    for ip in $(ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
        if [[ $ip == "${input_ip}" ]]; then
            return 0
        fi
    done
    return 1
}



# To Do
config_nfs()
{
    log_info "- configuring nfs target"
}

config_nfs_ipv6()
{
    log_info "- configuring ipv6 nfs target"
}

config_ssh_key()
{
    log_info "- Configuring ssh key"
}

config_path()
{
    log_info "- Configuring path"
}

config_core_collector()
{
    log_info "- Configuring collector (makedumpfile)"
}

config_post()
{
    log_info "- Configuring post option"
}

config_pre()
{
    log_info "- Configuring pre option"
}

config_extra()
{
    log_info "- Configuring extra option"
}

config_default()
{
    log_info "- Configuring default option"
}
