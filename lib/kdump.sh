#!/usr/bin/env bash

# In Fedora and upstream kernel, can't support crashkernel=auto kernel parameter,
# but we can check /sys/kernel/kexec_crash_size value, if equal to zero, so we need
# change kernel parameter crashkernel=<>M or other value

((LIB_KDUMP_SH)) && return || LIB_KDUMP_SH=1
. ../lib/log.sh

K_ARCH="$(uname -m)"
K_DEFAULT_PATH="/var/crash"
K_REBOOT="./K_REBOOT"
K_CONFIG="/etc/kdump.conf"
K_PATH="./KDUMP-PATH"
K_RAW="./KDUMP-RAW"
K_BACKUP_DIR="./backup"
readonly K_LOCK_AREA="/root"
readonly K_LOCK_SSH_ID_RSA=/root/.ssh/id_rsa_kdump_test
readonly K_RETRY_COUNT=1000

KPATH=${KPATH:-"${K_DEFAULT_PATH}"}
OPTION=${OPTION:-}
MP=${MP:-/}
LABEL=${LABEL:-label-kdump}
RAW=${RAW:-"no"}

install_rpm_package()
{
    if [[ $# -gt 0 ]];then
    yum install -y "$@" || log_error "Can not install rpm: $*"
        log_info "Install $* successful"
    fi
}

prepare_env()
{
    mkdir -p "${K_BACKUP_DIR}"
    cp /etc/kdump.conf "${K_BACKUP_DIR}"/
}

prepare_kdump()
{
    if [ ! -f "${K_REBOOT}" ]; then
        prepare_env
        local default
        default=/boot/vmlinuz-$(uname -r)
        [ ! -s "$default" ] && default=/boot/vmlinux-$(uname -r)
        /sbin/grubby --set-default="${default}"

        # for uncompressed kernel, i.e. vmlinux
        [[ "${default}" == *vmlinux* ]] && {
            log_info "- modifying /etc/sysconfig/kdump properly for 'vmlinux'."
            sed -i 's/\(KDUMP_IMG\)=.*/\1=vmlinux/' /etc/sysconfig/kdump
        }

        # check /sys/kernel/kexec_crash_size value and update if need.
        # need restart system when you change this value.
        grep -q 'crashkernel' <<< "${KERARGS}" || {
                [ "$(cat /sys/kernel/kexec_crash_size)" -eq 0 ] && {
                    log_info "MemTotal is:" "$(grep MemTotal /proc/meminfo)"
                    KERARGS+="$(def_kdump_mem)"
                }
        }

        [ "${KERARGS}" ] && {
            # need create a file/flag to sign we have do this.
            touch ${K_REBOOT}
            log_info "- changing boot loader."
            {
                /sbin/grubby    \
                    --args="${KERARGS}"    \
                    --update-kernel="${default}" &&
                if [ "${K_ARCH}" = "s390x" ]; then zipl; fi
            } || {
                log_error "- change boot loader error!"
            }
            log_info "- prepare reboot."
            reboot_system
        }

    fi
    #[ -f "${K_REBOOT}" ] && rm -f "${K_REBOOT}"

    # install kexec-tools package
    rpm -q kexec-tools || yum install -y kexec-tools || log_error "- kexec-tools install failed."

    # enable kdump service: systemd | sys-v
    /bin/systemctl enable kdump.service || /sbin/chkconfig kdump on || log_error "Error to enable Kdump"
}

restart_kdump()
{
    log_info "- retart kdump service."
    # delete kdump.img in /boot directory
    rm -f /boot/initrd-*kdump.img || rm -f /boot/initramfs-*kdump.img
    touch "${K_CONFIG}"
    /usr/bin/kdumpctl restart 2>&1 || /sbin/service kdump restart 2>&1 || log_error "Failed to start kdump!"
    log_info "kdump service start successful."
}

# Config default kdump memory
def_kdump_mem()
{
    local args=""
    if [[ "${K_ARCH}" = "x86_64" ]]; then args="crashkernel=160M"
    elif [[ "${K_ARCH}" = "ppc64" ]]; then args="crashkernel=320M"
    elif [[ "${K_ARCH}" = "s390x" ]]; then args="crashkernel=160M"
    elif [[ "${K_ARCH}" = "ppc64le" ]]; then args="crashkernel=320M"
    elif [[ "${K_ARCH}" = "aarch64" ]]; then args="crashkernel=2048M"
    elif [[ "${K_ARCH}" = i?86 ]]; then args="crashkernel=128M"
    fi
    echo "$args"
}

# create label
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
        echo "- failed to label $fstype with $label on $dev" && exit 1
    fi
}

# append option to kdump.conf
append_config()
{
    log_info "- modifying /etc/kdump.conf"
    if [ $# -eq 0 ]; then
        log_info "- Nothing to append."
        return 0
    fi

    while [ $# -gt 0 ]; do
        log_info "- removing existed old ${1%%[[:space:]]*} settings."
        sed -i "/^${1%%[[:space:]]*}/d" ${K_CONFIG}
        log_info "- adding new arguments '$1'."
        echo "$1" >> "${K_CONFIG}"
        shift
    done

    log_info "- show kdump.conf file."
    log_info $(grep -v ^# "${K_CONFIG}")
}

# config kdump.conf
configure_kdump_conf()
{
    # need accepte pramater from user.
    # there will include more branch case, like:
    # config_raw, config_dev_name, config_dev_uuid, config_dev_label, config_nfs, config_ssh, config_ssh_key
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
        log_error "- Null dump_device/uuid/label or type wrong."
    fi

}

config_nfs()
{
    echo "config nfs target"
}

config_nfs_ipv6()
{
    echo "config ipv6 nfs target"
}
#########################################
# Prepare communication env for client and server
# It will exit if program error
# Param:
#   $1 - Server Hostname
#   $2 - Client Hostname
# Global:
#   None
# Return:
#   0 - Config success
########################################
prepare_for_multihost()
{
    which nc || yum install -y nmap-ncat || yum install -y nc || log_error "Failed to install nc client"
}
#########################################
# Config SSH-Kdump in server and client
# When error trigger, It will exit
# Param:
#   $1 - Server Hostname
#   $2 - Client Hostname
# Global:
#    
# Return:
#   0  -  Success config 
#
######################################
config_ssh()
{
    yum install -y openssh-server openssh-clients || log_error "Failed to install openssh-server openssh-client"
    local server
    server=${SERVERS}
    local client
    client=${CLIENTS}
    if [[ $(get_role) == "client" ]]; then  # copy certification
        log_info "Run prepare_for_multihost as client"
        mkdir -p "/root/.ssh"
        cp ../lib/id_rsa ${K_LOCK_SSH_ID_RSA}
        chmod 0600 ${K_LOCK_SSH_ID_RSA}
        cp ../lib/id_rsa.pub "${K_LOCK_SSH_ID_RSA}.pub"
        chmod 0600 "${K_LOCK_SSH_ID_RSA}.pub"

        append_config "ssh root@${server}" || log_error "Error to config ssh target"
        if [[ "$(grep -o '[0-9.]\+' /etc/redhat-release)" =~ ^6 ]]; then
            append_config "link_delay 60"  # Some network interface, rhel 6 will wait network ready
        fi

        append_config "path ${K_DEFAULT_PATH}"
        append_config "sshkey ${K_LOCK_SSH_ID_RSA}"
        append_config "core_collector makedumpfile -l -F --message-level 1 -d 31"
        log_info "Config Kdump file successful"

        config_notify_at_client "${server}"
        ssh -o StrictHostKeyChecking=no -i ${K_LOCK_SSH_ID_RSA} "${server}" 'touch ${K_LOCK_AREA}/ssh_test' || log_error "Test ssh connection error"
        log_info "SSH connection build successful."
    elif [[ $(get_role) == "server" ]]; then
        log_info "Run prepare_for_multihost as server"
        mkdir -p "/root/.ssh"
        touch "/root/.ssh/authorized_keys"
        cat ../lib/id_rsa.pub >> "/root/.ssh/authorized_keys"
        restorecon -R "/root/.ssh/authorized_keys"

        systemctl restart sshd || service sshd restart || log_error "Failed to restart sshd"
        config_wait_at_server
    else
        log_error "Can not determine host role, Please check your hostname."
    fi
}
################################
# Only use at server side after config done
# Param 
#   None
# Return
#   0 - Wait successful
#   1 - Timeout
###############################
config_wait_at_server()
{
    nc -l 35412
}
################################
# Notify server config done after client config done
# Param 
#   $1 - Server Hostname
#   $2 - Sync name
# Return
#   0 - Wait successful
#   1 - Failed
###############################
config_notify_at_client()
{
    local count
    count=${K_RETRY_COUNT}
    local flag
    flag=1
    local server=$1
    while [[ $count -gt 0 ]]; do  # repeate to dump data to server
        echo "Success" > "/dev/tcp/${server}/35412"
        if [[ $? -eq 0 ]]; then
            flag=0
            break
        else
            sleep 10s
        fi
        (( count = count - 1 ))
    done

    if [[ ${flag} -eq 1 ]]; then
        log_error "Can not notificate server."
    fi
}
#############################################
# Only use at server side wait client trigger
# Param
#   None
# Global
#   None
# Return
#   None
##############################################
trigger_wait_at_server()
{
    nc -l 35413
}
############################################
# Notify Trigger Finished to server
# Param:
#  $1 - server hostname
# Global:
#  None
# Return
#  None
###########################################
trigger_notify_at_client()
{
    local count
    count=${K_RETRY_COUNT}
    local flag
    flag=1
    local server=$1
    while [[ $count -gt 0 ]]; do  # repeate to dump data to server
        echo "Success" > "/dev/tcp/${server}/35413"
        if [[ $? -eq 0 ]]; then
            flag=0
            break
        else
            sleep 10s
        fi
        (( count = count - 1 ))
    done

    if [[ ${flag} -eq 1 ]]; then
        log_error "Can not notificate server, timeout."
    fi

}

############################################
# Check roles in multiple host task
# Param:
# Global:
#   SERVERS - server ip or hostname
#   CLIENTS - client ip or hostname
# Return:
#   server - Role is server
#   client - Role is client 
###########################################
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

    log_error "Unable to determine roles, Please check your input."
}
############################################
# Check IP parameter is current host IP
# Param:
#   1 - IP address
# Global:
# Return:
#   0 - this IP is this host
#   1 - this IP is not this host
###########################################
is_ip_match_host()
{
    local inputIP=$1
    for ip in $(ip -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
        if [[ $ip == "${inputIP}" ]]; then
            return 0
        fi
    done
    return 1
}
config_ssh_key()
{
    echo "config ssh key"
}

config_ssh_ipv6()
{
    echo "config ipv6 ssh target"
}

config_path()
{
    echo "config path"
}

config_core_collector()
{
    echo "config collector (makedumpfile)"
}

config_post()
{
    echo "config post option"
}

config_pre()
{
    echo "config prepare option"
}

config_extra()
{
    echo "config extra option"
}

config_default()
{
    echo "config default option"
}
