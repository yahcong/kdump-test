#!/usr/bin/env bash

. ../lib/kdump.sh

K_DEFAULT_PATH="/var/crash"
C_REBOOT="./C_REBOOT"

crash-sysrq-c()
{
	# Maybe need disable avc check
	if [ ! -f ${C_REBOOT} ]; then
		prepare_kdump
		# add config kdump.conf in here if need
		restart_kdump
		echo "- boot to 2nd kernel"
		touch "${C_REBOOT}"
		sync
		echo c > /proc/sysrq-trigger
	else
		rm -f "${C_REBOOT}"
	fi

	# add check vmcore test in here if need
	echo "- get vmcore file"
	ls -lt ${K_DEFAULT_PATH}/*/ | grep vmcore
	[ $? -ne 0 ] && echo "- get vmocre failed!" && exit 1
	echo "- get vmcore successful!"

}

echo "- start"
crash-sysrq-c
