#!/usr/bin/env bash

# Copyright (c) 2016 Red Hat, Inc. All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Author: Yahuan Cong<ycong@redhat.com>

. ../lib/kdump.sh
. ../lib/kdump_report.sh
. ../lib/crash.sh

summary_test_result()
{
        sed -i '1i\+-------- Test Result -------+' "${K_TEST_SUMMARY}"
        echo -e "Total:\c" >> "${K_TEST_SUMMARY}"
        echo -e "\t/Passed:$(grep -o 'Pass' "${K_TEST_SUMMARY}" | wc -l)\c" >> "${K_TEST_SUMMARY}"
        echo -e "\t/Failed:$(grep -o 'Fail' "${K_TEST_SUMMARY}" | wc -l)" >> "${K_TEST_SUMMARY}"
        echo "+-----------------------------+" >> "${K_TEST_SUMMARY}"
        report_file "${K_TEST_SUMMARY}"
}

log_info "- Start"
summary_test_result
