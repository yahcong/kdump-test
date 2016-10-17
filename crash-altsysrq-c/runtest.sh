#!/usr/bin/env bash

. ../lib/kdump.sh
. ../lib/crash.sh
. ../lib/log.sh

C_REBOOT="./C_REBOOT"

load_altsysrq_driver()
{
	mkdir altsysrq
	cd altsysrq
	cp ../altsysrq.c .
	cp ../Makefile.altsysrq Makefile
	unset ARCH
    ( make && insmod ./altsysrq.ko )|| log_error "- make/insmod altsysrq module fail"
	export ARCH
    ARCH=$(uname -i)
	cd ..
}

crash_altsysrq_c()
{
	if [ ! -f ${C_REBOOT} ]; then
        prepare_kdump
        restart_kdump
		load_altsysrq_driver
		touch "${C_REBOOT}"
		log_info "- boot to 2nd kernel"
		echo 1 > /proc/sys/kernel/sysrq
		sync
		echo c > /proc/driver/altsysrq
		log_error "- can't arrive here!"
	else
		rm "${C_REBOOT}"
	fi

    check_vmcore_file
    ready_to_exit
}

log_info "- start"
crash_altsysrq_c
