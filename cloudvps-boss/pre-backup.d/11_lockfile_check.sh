#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2015 CloudVPS. (CloudVPS Backup to Object Store Script)
# Author: Remy van Elst, https://raymii.org
# 
# This program is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by the 
# Free Software Foundation; either version 2 of the License, or (at your 
# option) any later version.
# 
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of 
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU 
# General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along 
# with this program; if not, write to the Free Software Foundation, Inc., 
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# 

VERSION="1.7"
TITLE="CloudVPS Boss Lockfile Check ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

DUPLICITY_LOCKFILE="$(find /root/.cache/duplicity -iname '*.lock' 2>&1 | head -n 1)"

if [[ ! -z "${DUPLICITY_LOCKFILE}" ]]; then
    if [[ -f "${DUPLICITY_LOCKFILE}" ]]; then
        lecho "Duplicity Lockfile found"
        FILETIME="$(stat -c %Y ${DUPLICITY_LOCKFILE})"
        CURRTIME="$(date +%s)"
        TIMEDIFF="$(( (CURRTIME - FILETIME) / 84600))"
        if [[ ${TIMEDIFF} != 0 ]]; then
            lecho "Lockfile is older thay 24 hours. Killing running Duplicity and removing lockfile."
            chmod -x "/etc/cloudvps-boss/post-fail-backup.d/20-failure-notify.sh"
            pkill -9 duplicity >/dev/null 2>&1
            sleep 1
            pkill -9 duplicity >/dev/null 2>&1
            sleep 1
            pkill -9 duplicity >/dev/null 2>&1
            sleep 1
            rm "${DUPLICITY_LOCKFILE}"
            if [[ $? -ne 0 ]]; then
                lerror "Cannot remove lockfile"
                chmod +x "/etc/cloudvps-boss/post-fail-backup.d/20-failure-notify.sh"
                exit 1
            fi
            chmod +x "/etc/cloudvps-boss/post-fail-backup.d/20-failure-notify.sh"
        else
            lecho "Lockfile exists but is not older than 24 hours."
            pgrep duplicity
            if [[ $? -ne 0 ]]; then
                lerror "Cannot find running duplicity process. This is not good."
                exit 1
            fi
            echo "Duplicity is still running. Seems OK."
            touch /etc/cloudvps-boss/status/24h
        fi
        lecho "Lockfile variable set but not a file. Lockfile var contents: ${DUPLICITY_LOCKFILE}."
    fi
    lecho "Lockfile not found."
fi

