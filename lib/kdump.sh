#!/usr/bin/env bash

# In Fedora and upstream kernel, can't support crashkernel=auto kernel parameter,
# but we can check /sys/kernel/kexec_crash_size value, if equal to zero, so we need
# change kernel parameter crashkernel=<>M or other value

K_ARCH="$(uname -m)"
K_REBOOT="./K_REBOOT"

prepare_kdump()
{
	#KERARGS=""
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
			echo "prepare reboot."
			/usr/bin/sync; /usr/sbin/reboot
		}

	fi
	#[ -f "${K_REBOOT}" ] && rm -f "${K_REBOOT}"

	# install kexec-tools package
	rpm -q kexec-tools || yum install -y kexec-tools || echo "kexec-tools install failed."

	# enable kdump service: systemd | sys-v
	/bin/systemctl enable kdump.service || /sbin/chkconfig kdump on
}

restart_kdump()
{
	echo "- retart kdump service."
	K_CONFIG="/etc/kdump.conf"
	grep -v ^# "${K_CONFIG}"
	# delete kdump.img in /boot directory
	rm -f /boot/initrd-*kdump.img || rm -f /boot/initramfs-*kdump.img
	/usr/bin/kdumpctl restart 2>&1 | tee /tmp/kdump_restart.log || /sbin/service kdump restart 2>&1 | tee /tmp/kdump_restart.log
	rc=$?
	[ $rc -ne 0 ] && echo "- kdump service start failed." && exit 1
	echo "- kdump service start normal."
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
	echo "config kdump configuration"
}

config_raw()
{
	echo "config raw"
}

config_dev_name()
{
	echo "config device name"
}

config_dev_uuid()
{
	echo "config device uuid"
}

config_dev_label()
{
	echo "config device label"
}

config_dev_softlink()
{
	echo "config device softlink"
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
