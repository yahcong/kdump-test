#!/usr/bin/env bash

. ./kdump.sh

# This file will test 'crash' command.

check_vmcore_file()
{
	echo "- get vmocre file"
	ls -lt ${K_DEFAULT_PATH}/*/ | grep vmcore
	[ $? -ne 0 ] && echo "- get vmcore failed!" && exit 1
	echo "- get vmcore successful!"
}

analyse_by_crash()
{
	echo "analyse vmcore by crash commend"
}

analyse_live()
{
	echo "analyse in live system"
}

analyse_by_basic()
{
	echo "analyse vmcore use basic option"
}

analyse_by_gdb()
{
	echo "analyse vmcore by gdb"
}

analyse_by_readelf()
{
	echo "analyse vmcore by readelf"
}

analyse_by_dmesg()
{
	echo "analyse vmcore-dmesg.txt"
}

analyse_by_trace_cmd()
{
	echo "analyse vmcore by trace_cmd"
}

analyse_by_gcore_cmd()
{
	echo "analyse vmcore by gcore_cmd"
}
