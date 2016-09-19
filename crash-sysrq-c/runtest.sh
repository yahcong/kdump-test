#!/usr/bin/env bash

. ../lib/kdump.sh

K_DEFAULT_PATH="/var/crash"

crash()
{
	# Maybe need disable avc check
	if [ ! -f ${C_REBOOT} ]
		prepare_kdump
		# add config kdump.conf in here if need
		restart_kdump
		# add check vmcore in here if need
		echo "- echo c > /proc/sysrq-trigger"
		echo c > /proc/sysrq-trigger
	fi
	[ -f ${C_REBOOT} ] && rm -f ${C_REBOOT}
	echo "- get vmcore file path"
	ls -lt "${K_DEFAULT_PATH}" | grep vmcore
}

echo "- start testing"
