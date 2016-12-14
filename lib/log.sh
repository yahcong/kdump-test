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

# Check if system is beaker environment.
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

############################
# Print Log info into ${K_LOG_FILE}
# Globals:
#   K_LOG_FILE
# Arguments:
#   $1 - Log level: ERROR, INFO, WARN
#   $2 - Log message
# Return:
#   None
############################
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

############################
# Report file to beaker server
# Param:
#   $1 - Full File Path
############################
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


# Print info message
# Param:
#   $1 - Info message
log_info()
{
    log "INFO" "$@"
}

# Print warn message
# Param:
#   $1 - Info message
log_warn()
{
    log "WARN" "$@"
}


# Print error message and exit
# Param:
#   $1 - Error message
log_error()
{
    log "ERROR" "$@"
    ready_to_exit 1
    exit 1
}


# Print test status before exiting
# Param:
#   $1 - test status (1- Fail  Other - Pass)
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
        if [[ $1 == "1" ]]; then
            log_info "- [FAIL] Please check test logs!"
            exit 1
        else
            log_info "- [PASS] Tests finished successfully!"
        fi
    fi
}


# Reboot system
reboot_system()
{
    /bin/sync

    if is_beaker_env; then
        /usr/bin/rhts-reboot
    else
        /sbin/reboot
    fi
}
