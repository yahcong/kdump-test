#!/usr/bin/env bash
# Basic Log Library for Kdump

# Copyright (C) 2016 Song Qihan <qsong@redhat.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.


((LIB_LOG_SH)) && return || LIB_LOG_SH=1
readonly K_LOG_FILE="./result.log"


# @usage: is_beaker_env
# @description: check it is a beaker environment
# #return: 0 - yes, 1 - no
is_beaker_env()
{
    if [ -f /usr/bin/rhts-environment.sh ]; then
        . /usr/bin/rhts-environment.sh
        return 0
    else
        log_info "- This is not executed in beaker."
        return 1
    fi
}


# @usage: log <level> <mesg>
# @description: Print Log info into ${K_LOG_FILE}
# @param1: level # ERROR, INFO, WARN
# @param2: mesg
log()
{
    local level="$1"
    shift
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $level $*" >> "${K_LOG_FILE}"
    if [[ $level == "ERROR" ]]; then
        echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $level $*" >&2
    else
        echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $level $*"
    fi
}


# @usage: report_file <filename>
# @description: report file to beaker server
# @param1: filename
report_file()
{
    local filename="$1"
    if [[ -f "${filename}" ]]; then
        if is_beaker_env; then
            rhts-submit-log -l "$filename"
        else
            cat ${filename}
        fi
    else
        # if file doesn't exist.
        log_warn "- File ${filename} doesn't exist!"
    fi
}


# @usage: log_info <mesg>
# @description: log INFO message
# @param1: mesg
log_info()
{
    log "INFO" "$@"
}

# @usage: log_warn <mesg>
# @description: log WARN message
# @param1: mesg
log_warn()
{
    log "WARN" "$@"
}


# @usage: log_error <mesg>
# @description: log ERROR message and exit
# @param1: mesg
log_error()
{
    log "ERROR" "$@"
    ready_to_exit 1
    exit 1
}


# @usage: ready_to_exit <exit_code>
# @description:
#       report test log/status and exit
#       abort test if fail
# @param1: exit_code  # (1- Fail  Other - Pass)
ready_to_exit()
{
    report_file "${K_LOG_FILE}"

    if is_beaker_env; then
        if [[ $1 == "1" ]]; then
            report_result "${TEST}" "FAIL" "1"
            rhts-abort -t recipeset
        else
            report_result "${TEST}" "PASS" "0"
        fi
    else
        [[ $1 == "1" ]] && {
            log_info "- [FAIL] Please check test logs!"
            exit 1
        }
        log_info "- [PASS] Tests finished successfully!"
        exit 0
    fi
}


# @usage: reboot_system
# @description: reboot system
reboot_system()
{
    /bin/sync

    if is_beaker_env; then
        /usr/bin/rhts-reboot
    else
        /sbin/reboot
    fi
}
