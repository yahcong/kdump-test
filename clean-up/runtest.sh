#!/usr/bin/env bash

. ../lib/kdump.sh
. ../lib/log.sh

clean_up()
{
    if [ -d "${KPATH}" ]; then
        log_info "- Remove all vmcore* file in ${KPATH}"
        rm -rf "${KPATH}"/*
    else
        log_info "- Remove all vmcore* file in ${K_DEFAULT_PATH}"
        rm -rf "${K_DEFAULT_PATH}"/*
    fi

    log_info "- Remove all temporary files."
    rm -f ../lib/"${K_REBOOT}"

    log_info "- Revert kdump.conf file."
    cp -f ../lib/"${K_BACKUP_DIR}"/kdump.conf /etc/kdump.conf

    log_info "- Clean up end."
}
