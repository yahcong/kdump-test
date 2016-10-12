#!/usr/bin/env bash

. ../lib/kdump.sh

load_altsysrq_driver()
{
	mkdir altsysrq
	cd altsysrq
	cp ../altsysrq.c .
	cp ../Makefile.altsysrq Makefile
	unset ARCH
	make && insmod ./altsysrq.ko || (echo "- make/insmod altsysrq module fail" && exit 1)
	export ARCH=$(uname -i)
	cd ..
}

crash-altsysrq-c()
{
	if [ ! -f ${C_REBOOT} ]; then
		load_altsysrq_driver
		touch "${C_REBOOT}"
		echo "- boot to 2nd kernel"
		echo 1 > /proc/sys/kernel/sysrq
		sync
		echo c > /proc/driver/altsysrq
		echo "- can't arrive here!"
	else
		rm "${C_REBOOT}"
	fi

	# check vmcore file
	echo "- get vmcore file"
	ls -lt ${K_DEFAULT_PATH}/*/ | grep vmcore
	[ $? -ne 0 ] && echo "- get vmocre failed!" && exit 1
	echo "- get vmcore successful!"
}

echo "- start"
crash-altsysrq-c
