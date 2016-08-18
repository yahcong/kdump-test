#!/usr/bin/env bash

# In Fedora and upstream kernel, can't support crashkernel=auto kernel parameter,
# but we can check /sys/kernel/kexec_crash_size value, if equal to zero, so we need
# change kernel parameter crashkernel=<>M or other value
prepare_kdump()
{
	# check /sys/kernel/kexec_crash_size value and update if need.
	# need restart system when you change this value.
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
}

config_raw()
{
	#
}

config_dev_name()
{
	#
}

config_dev_uuid()
{
	#
}

config_dev_label()
{
	#
}

config_nfs()
{
	#
}

config_ssh()
{
	#
}

config_ssh_key()
{
	#
}

config_path()
{
	#
}

config_core_collector()
{
	#
}

config_post()
{
	#
}

config_pre()
{
	#
}

config_extra()
{
	#
}

config_default()
{
	#
}

# trigger methods, the common methods is 'echo c > /proc/sysrq'
trigger_echo_c()
{
	#
}

trigger_AltSysC()
{
	#
}

tirgger_kernel_BUG()
{
	#
}

trigger_kernel_panic()
{
	#
}

trigger_kernel_lockup()
{
	#
}

trigger_kernel_panic_on_warn()
{
	#
}

# check vmcore whether it exists, just try to get it.
get_vmcore()
{
	#
}

# analyse vmcore
analyse_live()
{
	#
}

analyse_vmcore_basic()
{
	#
}

analyse_vmcore_readelf()
{
	#
}

analyse_vmcore_gdb()
{
	#
}

# special dump method/target
config_raid()
{
	# include raid 0, 1, 5, 10
}

config_iscsi()
{
	#
}

config_fcoe()
{
	#
}

config_ssh_ipv6()
{
	#
}

config_nfs_ipv6()
{
	#
}

config_bridge()
{
	#
}

config_vlan()
{
	#
}

config_bonding()
{
	#
}

config_kvm_guest()
{
	#
}
