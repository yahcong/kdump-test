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


((LIB_LOG_SH)) && return ||LIB_LOG_SH=1

readonly K_LOG_FILE="./result.log"

############################
# Print Log info into ${K_LOG_FILE}
# Globals:
#   K_LOG_FILE
# Arguments:
#   $1 - Log level: Debug, Info, ERROR
#   $2 - Log message
# Return:
#   None
############################ 
log() {
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
# report file to beaker server 
# Globals:
#   None
# Arguments:
#   $1 - Full File Path
# Return:
#   None
############################ 
report_file()
{
    local filename="$1"
    if [[ -f "${filename}" ]]; then
        if [ -z "${JOBID}" ] && [ -z "${TASKID}" ]; then
            rhts-submit-log -l "$filename"
        fi
    else
        log_info "file ${filename} not exist!"
    fi
}

###########################
# Print Debug Info
# Globals
#   None
# Arguments:
#   $1 - Debug Output Info
# Return:
#   None
##########################
log_info() 
{
    log "INFO" "$@"
}

#############################################
# Print Error Info and report system status
# Globals
#   None
# Arguments:
#   $1 - Error Output Info
# Return:
#   None
#############################################
log_error()
{
    log "ERROR" "$@"
    ready_to_exit
    exit 1
}

##############################################
# Do sth. Before Exit
# Globals
#   None
# Arguments:
#   $1 - Error Output Info
# Return:
#   None
##############################################
ready_to_exit()
{
  report_file "${K_CONFIG}"
  report_file "${K_LOG_FILE}"
  cp "${K_BACKUP_DIR}"/kdump.conf /etc/kdump.conf
}

#############################################
# Reboot system
# Globals:
#   None
# Arguments:
#   None
# Return:
#   None
###########################################
reboot_system()
{
  /usr/bin/sync
  if [ -z "${TEST}" ]; then
    rhts-reboot
  else
    /usr/sbin/reboot
  fi
}

