#!/usr/bin/env bash

((LIB_KDUMP_SH)) && return || LIB_KDUMP_SH=1
. ../lib/log.sh

K_ARCH="$(uname -m)"
K_DIST_NAME="$(rpm -E %{?dist} | sed 's/[.0-9]//g')"
K_DIST_VER="$(rpm -E %{?dist} | sed 's/[^0-9]//g')"

K_CONFIG="/etc/kdump.conf"
K_DEFAULT_PATH="/var/crash"
K_SSH_CONFIG="${HOME}/.ssh/config"

# Test Parameters:
KDEBUG=${KDEBUG:-"no"}

KPATH=${KPATH:-${K_DEFAULT_PATH}}
OPTION=${OPTION:-}
MP=${MP:-/}
LABEL=${LABEL:-label-kdump}
RAW=${RAW:-no}
TESTAREA=${TESTAREA:-"/mnt/testarea"}


# Test dir
K_TMP_DIR="${TESTAREA}/tmp"
K_INF_DIR="${TESTAREA}/info"
K_BAK_DIR="${K_TMP_DIR}/bk"

K_REBOOT="${K_TMP_DIR}/K_REBOOT"
C_REBOOT="./C_REBOOT"

# KDUMP-PATH stores the full path to vmcore files.
# e.g. cat KDUMP-PATH: ${MP%/}${KPATH}
K_PATH="${K_TMP_DIR}/KDUMP-PATH"
K_RAW="${K_TMP_DIR}/KDUMP-RAW"

K_HWINFO_FILE="${K_INF_DIR}/hwinfo.log"
K_INITRAMFS_LIST="${K_INF_DIR}/initramfs.list"

K_PREFIX_FWD="${K_INF_DIR}/FIREWALLD"
K_PREFIX_IPT="${K_INF_DIR}/IPTABLES"
K_PREFIX_SSH="${K_INF_DIR}/SSHD_ENABLE"

readonly K_LOCK_AREA="/root"
readonly K_LOCK_SSH_ID_RSA="${K_LOCK_AREA}/.ssh/id_rsa_kdump_test"
readonly K_RETRY_COUNT=1000

[[ "${KDEBUG}" == "yes" ]] && set -x

[ ! -d "${K_TMP_DIR}" ] &&  mkdir -p "${K_TMP_DIR}"
[ ! -d "${K_INF_DIR}" ] &&  mkdir -p "${K_INF_DIR}"
[ ! -d "${K_BAK_DIR}" ] &&  mkdir -p "${K_BAK_DIR}"


# @usage: backup_files
# @description: backup kdump config
backup_files()
{
    cp "${K_CONFIG}" "${K_BAK_DIR}"/
}


# @usage: install_rpm <pkg> <pkg>
# @description: install rpm packages
# @param1: list of pkg
install_rpm()
{
    if [[ $# -gt 0 ]]; then
        for pkg in $@; do
            rpm -q $pkg || yum install -y $pkg || log_error "- Install package $pkg failed!"
        done
        log_info "- Installed $* successfully"
    fi
}


# @usage: install_rpm <pkg> <repo>
# @description: install rpm package from the repo
# @param1: pkg
# @param2: repo
install_rpm_from_repo()
{
    if [[ $# -gt 2 ]]; then
        local pkg=$1
        local repo=$2
        rpm -q $pkg || yum install -y --enablerepo=$1 $2
        [[ $? -ne 0  ]] && log_error "- Install package $pkg from $repo failed!"
        log_info "- Installed $pkg from $repo successfully"
    fi
}


# @usage: make_module <module_name>
# @description: Make a module
# @param1: name  # name of the module
make_module()
{
    local name=$1

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


##  Preparing Kdump/Crash Test Environment ###

# @usage: multihost_prepare
# @description: install required packakges for multi-host tests
multihost_prepare()
{
    which nc || yum install -y nmap-ncat || yum install -y nc || log_error "- Failed to install nc client"
}


# @usage: crash_prepare
# @description: install required packakges for crash test
crash_prepare()
{
    install_rpm kernel-debuginfo crash
}


# @usage: kdump_prepare
# @description: to make sure crash mem is reserved and kdump is started.
kdump_prepare()
{
    if [ ! -f "${K_REBOOT}" ]; then
        backup_files
        local default=/boot/vmlinuz-$(uname -r)
        [ ! -s "$default" ] && default=/boot/vmlinux-$(uname -r)

        # temporarily comment out this line to set default to grubby
        # seems if it's executed too quickly with rebuilding kdump img,
        # system would hange after rebooting.
        # need to figure out why it requires to set default to grub
        # /sbin/grubby --set-default="${default}"

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
                    KERARGS+=" $(get_kdump_mem)"
                }
        }

        [ "${KERARGS}" ] && {
            # K_REBOOT is to mark system's been rebooted for kernel cmdline change.
            touch "${K_REBOOT}"
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

    # check again if memory is reserved for kdump.
    # if not, print out cmdline and exit.
    if [ "$(cat /sys/kernel/kexec_crash_size)" -eq 0 ]; then
        log_info "- Kernel Boot Cmdline is: $(cat /proc/cmdline)"
        log_error "- No memory is reserved for crashkernel!"
    fi

    # install kexec-tools package
    install_rpm kexec-tools

    # enable kdump service: systemd
    /bin/systemctl enable kdump.service || /sbin/chkconfig kdump on || log_error "- Failed to enable kdump!"
    log_info "- Enabled kdump service."
    kdump_restart
}


# @usage: get_kdump_mem
# @description: get default memory reserved for crashkernel
get_kdump_mem()
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


# @usage: kdump_restart
# @description: restart kdump service
kdump_restart()
{
    log_info "- Restart kdump service."

    # delete initrd*kdump.img and update timestamp of kdump.conf
    rm -f /boot/initrd-*kdump.img || rm -f /boot/initramfs-*kdump.img
    touch "${K_CONFIG}"

    /usr/bin/kdumpctl restart 2>&1 || /sbin/service kdump restart 2>&1 || log_error "- Failed to start kdump!"
    log_info "- Kdump service starts successfully."
}


###  Configuring KDUMP.CONF ###

# @usage: config_kdump_any <config>
# @description:
#   append config to kdump.config
#   kdump service is NOT restarted after configuring
# @param1: config
config_kdump_any()
{
    log_info "- Modifying ${K_CONFIG}"
    local config="$1"

    if [[ -z "$config" ]]; then
        log_info "- Nothing to modify."
        return
    fi

    log_info "- Removing existing ${1%%[[:space:]]*} settings."
    sed -i "/^${1%%[[:space:]]*}/d" ${K_CONFIG}
    log_info "- Adding new config '$1'."
    echo "$config" >> "${K_CONFIG}"

}


# @usage: LabelFS <fstype> <dev> <mntpnt> <label>
# @description: add label to specified fs
# @param1: fstype
# @param2: device
# @param3: mount point
# @param4: label
label_fs()
{
    local fstype="$1"
    local dev="$2"
    local mp="$3"
    local label="$4"

    case "$fstype" in
        xfs)
            umount "$dev" &&
            xfs_admin -L "$label" "$dev" &&
            mount "$dev" "$mp"
            ;;
        ext[234])
            e2label "$dev" "$label"
            ;;
        btrfs)
            umount "$dev" &&
            btrfs filesystem label "$dev" "$label" &&
            mount "$dev" "$mp"
            ;;
        *)
            false
            ;;
    esac

    [ $? -ne 0 ] && log_error "- Failed to label $fstype with $label on $dev"
}


# @usage: config_kdump_fs
# @description:
#    configure local dump target in kdump.conf
#    restart kdump service after configuring
# @param1: MP      # mount point of dump device. default to '/'
# @param2: KPATH   # specify 'path' in kdump.conf. default to '/var/crash'.
# @param3: OPTION  # 'uuid', 'label' or 'softlink'
# @param4: LABEL   # Only applicable when OPTION=label. Specifying a label to the particular fs
# @param5: RAW     # 'yes' means raw dump, default to 'no'
config_kdump_fs()
{

    log_info "- Editing kdump configuration"
    local dev=""
    local fstype=""
    local target=""

    # get dev, fstype
    if [ "yes" == "$RAW" -a -f "${K_RAW}" ]; then
        dev=$(cut -d" " -f1 "${K_RAW}")
        fstype=(cut -d" " -f2 "${K_RAW}")
        rm -f "${K_RAW}"
        mkfs."${fstype[0]}" "$dev" && mount "$dev" "$MP"
    else
        dev=$(findmnt -kcno SOURCE "$MP")
        fstype=$(findmnt -kcno FSTYPE "$MP")
    fi

    # get target
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
        config_kdump_any "raw $target"
        sed -i "/[ \t]\\$MP[ \t]/d" /etc/fstab
        echo "$dev $fstype" > "${K_RAW}"
    elif [ -n "$fstype" -a -n "$target" ]; then
        config_kdump_any "$fstype $target"
        config_kdump_any "path $KPATH"
        mkdir -p "$MP/$KPATH"
        # tell crash analyse procedure where to find vmcore
        echo "${MP%/}${KPATH}" > "${K_PATH}"
    else
        log_error "- Null dump_device/uuid/label or wrong type."
    fi

    kdump_restart
}


# @usage: config_kdump_filter <opt>
# @description:
#    configure Kdump using makedumpfile to collect vmcore.
#    restart kdump service after configuring
# @param1: opt  # options passed to makedumpfile. default to "-c -d 31"
config_kdump_filter()
{
    local opt

    if [[ -n "$1" ]]; then
        opt="$1"
    elif grep -qE '^(ssh|raw)' ${K_CONFIG}; then
        opt="-F -c -d 31"
    else
        opt="-c -d 31"
    fi

    config_kdump_any "core_collector makedumpfile ${opt}"
    kdump_restart
}


###  Triggering Crash ###

# @usage: trigger_sysrq_crash
# @description: trigger sysrq-trigger crash
trigger_sysrq_crash()
{
    touch "${C_REBOOT}"
    sync;sync;sync
    log_info "- Triggering crash."
    echo c > /proc/sysrq-trigger

    sleep 60
    log_error "- Failed to trigger crash after waiting for 60s."
}


