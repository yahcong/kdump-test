#!/usr/bin/env bash

# In Fedora and upstream kernel, can't support crashkernel=auto kernel parameter,
# but we can check /sys/kernel/kexec_crash_size value, if equal to zero, so we need
# change kernel parameter crashkernel=<>M or other value

K_ARCH="$(uname -m)"
K_DEFAULT_PATH="/var/crash"
K_REBOOT="./K_REBOOT"
K_CONFIG="/etc/kdump.conf"
K_PATH="./KDUMP-PATH"
K_RAW="./KDUMP-RAW"

C_REBOOT="./C_REBOOT"

KPATH=${KPATH:-"${K_DEFAULT_PATH}"}
OPTION=${OPTION:-}
MP=${MP:-/}
LABEL=${LABEL:-label-kdump}
RAW=${RAW:-"no"}

prepare_kdump()
{
	if [ ! -f "${K_REBOOT}" ]; then
		local default=/boot/vmlinuz=`uname -r`
		[ ! -s "$default" ] && default=/boot/vmlinux-`uname -r`
		/sbin/grubby --set-default="${default}"
	
		# for uncompressed kernel, i.e. vmlinux
		[[ ${defalt} == *vmlinux* ]] && {
			echo "- modifying /etc/sysconfig/kdump properly for 'vmlinux'."
			sed -i 's/\(KDUMP_IMG\)=.*/\1=vmlinux/' /etc/sysconfig/kdump
		}

		# check /sys/kernel/kexec_crash_size value and update if need.
		# need restart system when you change this value.
		grep -q 'crashkernel' <<< "${KERARGS}" || {
			[ `cat /sys/kernel/kexec_crash_size` -eq 0 ] && {
				echo "`grep MemTotal /proc/meminfo`"
				KERARGS+="`def_kdump_mem`"
			}
		}
		[ "${KERARGS}" ] && {
			# need create a file/flag to sign we have do this.
			touch ${K_REBOOT}
			echo "- changing boot loader."
			{
				/sbin/grubby	\
					--args="${KERARGS}"	\
					--update-kernel="${default}" &&
				if [ ${K_ARCH} = "s390x" ]; then zipl; fi
			} || {
				echo "- change boot loader error!"
				exit 1
			}
			echo "- prepare reboot."
			/usr/bin/sync; /usr/sbin/reboot
		}

	fi
	#[ -f "${K_REBOOT}" ] && rm -f "${K_REBOOT}"

	# install kexec-tools package
	rpm -q kexec-tools || yum install -y kexec-tools || echo "- kexec-tools install failed."

	# enable kdump service: systemd | sys-v
	/bin/systemctl enable kdump.service || /sbin/chkconfig kdump on
}

restart_kdump()
{
	echo "- retart kdump service."
	# delete kdump.img in /boot directory
	rm -f /boot/initrd-*kdump.img || rm -f /boot/initramfs-*kdump.img
	touch "${K_CONFIG}"
	/usr/bin/kdumpctl restart 2>&1 | tee /tmp/kdump_restart.log || /sbin/service kdump restart 2>&1 | tee /tmp/kdump_restart.log
	[ $? -ne 0 ] && echo "- kdump service start failed." && exit 1
	echo "- kdump service start successful."
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
	echo "- modifying /etc/kdump.conf"
	if [ $# -eq 0 ]; then
		echo "- Nothing to append."
		return 0
	fi

	while [ $# -gt 0 ]; do
		echo "- removing existed old ${1%%[[:space:]]*} settings."
		sed -i "/^${1%%[[:space:]]*}/d" ${K_CONFIG}
		echo "- adding new arguments '$1'."
		echo "$1" >> "${K_CONFIG}"
		shift
	done
	
	echo "- show kdump.conf file."
	cat "${K_CONFIG}"
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
	echo "- config kdump configuration"
	local dev=""
	local fstype=""
	local target=""

	# get dev, fstype
	if [ "yes" == "$RAW" -a -f "${K_RAW}" ]; then
		dev=`cut -d" " -f1 ${K_RAW}`
		fstype=`cut -d" " -f2 ${K_RAW}`
		rm -f ${K_RAW}
		mkfs.$fstype $dev && mount $dev $MP
	else
		dev=`findmnt -kcno SOURCE $MP`
		fstype=`findmnt -kcno FSTYPE $MP`
	fi
	
	case $OPTION in
		uuid)
			# some partitions have both UUID= and PARTUUID=, we only want UUID=
			target=`blkid $dev -o export -c /dev/null | grep '\<UUID='`
			;;
		label)
			target=`blkid $dev -o export -c /dev/null | grep LABEL=`
			if [ -z "$target" ]; then
				label_fs $fstype $dev $MP $LABEL
				target=`blkid $dev -o export -c /dev/null | grep LABEL=`
			fi
			;;
		softlink)
			ln -s $dev $dev-softlink
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
		mkdir -p $MP/$KPATH
		# tell crash analyse procedure where to find vmcore
		echo "${MP%/}${KPATH}" > ${K_PATH}
	else
		echo "- Null dump_device/uuid/label or type wrong." && exit 1
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

config_ssh()
{
	echo "config ssh target"
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

# trigger methods, the common methods is 'echo c > /proc/sysrq'
trigger_echo_c()
{
	echo "trigger by echo c > /proc/sysrq-trigger"
}

trigger_AltSysC()
{
	echo "trigger by AltSysC button"
}

tirgger_kernel_BUG()
{
	echo "trigger by kernel function BUG()"
}

trigger_kernel_panic()
{
	echo "trigger by kernel function panic()"
}

trigger_kernel_lockup()
{
	echo "trigger by hard lockup"
}

trigger_kernel_panic_on_warn()
{
	echo "trigger by kernel function panic_on_warn()"
}
