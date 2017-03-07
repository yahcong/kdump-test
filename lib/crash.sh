#!/usr/bin/env bash

((LIB_CRASH_SH)) && return || LIB_CRASH_SH=1

. ../lib/log.sh
. ../lib/kdump.sh


# @usage: get_vmcore_path <vmcore_format>
# @description:
#   get the full path to the vmcore
#   it searches vmcore/vmcroe.flat/vmcore-dmesg based on the <vmcore_format>
# @param1: vmcore_format # "vmcore" "flat" "dmesg". default to "dmesg"
# @return: if >1 vmcore is found, exit with error.
get_vmcore_path()
{
    local vmcore_format=$1
    local vmcore_path=""

    local vmcore_name="vmcore"
    if [[ ${vmcore_format} == "flat" ]]; then
        vmcore_name="vmcore.flat"
    elif [[ ${vmcore_format} == "dmesg" ]]; then
        vmcore_name="vmcore-dmesg.txt"
    fi

    [ -f "${K_PATH}" ] && vmcore_path=$(cat "${K_PATH}") || vmcore_path="${K_DEFAULT_PATH}"

    if [ -f "${K_NFS}" ]; then
        vmcore_path="$(cat "${K_NFS}")${vmcore_path}" # need update
    fi

    local vmcore_full_path
    vmcore_full_path=$(find "${vmcore_path}" -newer /etc/kdump.conf -name "${vmcore_name}" -type f)
    count=$(echo $vmcore_full_path | wc -w)
    if [ $count -gt 1 ]; then
        log_error "- More than 1 vmcore is found in ${vmcore_path}. Expect 1 or 0."
    else
        echo $vmcore_full_path
    fi
}


# @usage: validate_vmcore_exists <vmcore_format>
# @description:
#   check whether the vmcore exists
#   it checks vmcore/vmcroe.flat/vmcore-dmesg based on the <vmcore_format>
# @param1: vmcore_format # "vmcore" "flat" "dmesg". default to "dmesg"
# @return: if no vmcore is found, exit with error.
validate_vmcore_exists()
{
    local vmcore_format=$1

    log_info "- Validate if vmcore exists"
    local vmcore_full_path=$(get_vmcore_path $vmcore_format)

    if [ ! -z "${vmcore_full_path}" ]; then
        log_info "- Found vmcore file at ${vmcore_full_path}"
    else
        log_error "- No vmcore file is found."
    fi
}

# @usage: validate_vmcore_not_exists <vmcore_format>
# @description:
#   check whether the vmcore doesn't exists
#   it checks vmcore/vmcroe.flat/vmcore-dmesg based on the <vmcore_format>
# @param1: vmcore_format # "vmcore" "flat" "dmesg". default to "dmesg"
# @return: if vmcore is found, exit with error.
validate_vmcore_not_exists()
{
    local vmcore_format=$1

    log_info "- Validate if vmcore not exists"
    local vmcore_full_path=$(get_vmcore_path $vmcore_format)

    if [ ! -z "${vmcore_full_path}" ]; then
        log_error "- Found vmcore file at ${vmcore_full_path}"
    else
        log_info "- No vmcore file is found."
    fi
}


# @usage: crash_command <args> <vmlinux> <vmcore>
# @description: run crash cmd to analyze vmcore with pre-defined crash.cmd
# @param1: args  # crash args
# @param2: aux   # location of vmlinux
# @param3: core  # location of vmcore
crash_command()
{
    local args=$1
    local aux=$2
    local core=$3

    touch ${TESTAREA}/crash.log

    log_info "- Check command output of this session"
    log_info "- # crash ${args} -i ${TESTAREA}/crash.cmd ${aux} ${core}"
    crash ${args} -i "${TESTAREA}/crash.cmd" ${aux} ${core} > "${TESTAREA}/crash.log" 2>&1 <<EOF
EOF
    code=$?
    report_file ${TESTAREA}/crash.cmd
    report_file ${TESTAREA}/crash.log

    [ ${code} -ne 0 ] && log_error "- Crash returns error code ${code}"
}


# @usage: crash_command <args> <vmlinuz> <vmcore>
# @description: analyze vmcore by crash
# @param1: args  # crash args
# @param2: aux   # vmlinuz with debuginfo
# @param3: core  # location of vmcore
analyse_by_crash()
{
    # Also check command output of this session.
    # See BZ1203238: kmem -S -I kmalloc-8,kmalloc-16
    cat <<EOF >>"${TESTAREA}/crash.cmd"
help -v
help -m
help -n
swap
mod
mod -S
runq
foreach bt
foreach files
mount
mount -f
vm
net
mach -m
search -u deadbeef
set
set -p
set -v
bt
bt -t
bt -r
bt -T
bt -l
bt -a
bt -f
bt -e
bt -E
bt -F
bt 0
ps
ps -k
ps -u
ps -s
dev
kmem -i
kmem -s
kmem -S -I kmalloc-8,kmalloc-16
task
p jiffies
sym jiffies
rd -d jiffies
set -c 0
EOF

    # In order for the "irq -u" option to work, the architecture
    # must have either the "no_irq_chip" or the "nr_irq_type" symbols to exist.
    # But s390x has none of them:
    if [ "$(uname -m)" != "s390x" ]; then
        cat <<EOF >>"${TESTAREA}/crash.cmd"
irq
irq -b
irq -u
exit
EOF
    fi

    local vmlinux="/usr/lib/debug/lib/modules/$(uname -r)/vmlinux"
    [ ! -f "${vmlinux}" ] && log_error "- Vmlinux is not found."

    local vmcore=$(get_vmcore_path)
    crash_command "" "${vmlinux}" "${vmcore}"
}



# To-Do
analyse_live()
{
    echo "analyse live system"
}

analyse_dmesg()
{
    echo "analyse vmcore-dmesg.txt"
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

analyse_by_trace_cmd()
{
    echo "analyse vmcore by trace_cmd"
}

analyse_by_gcore_cmd()
{
    echo "analyse vmcore by gcore_cmd"
}
