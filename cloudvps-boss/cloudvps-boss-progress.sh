#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2014 CloudVPS. (CloudVPS Backup to Object Store Script)
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

VERSION="1.6"
TITLE="CloudVPS Boss Progress Report ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

# only start if duplicity is running
if [[ -z "$(pgrep duplicity)" ]]; then
    lerror "Duplicity not running."
    exit
fi

if [[ -f "/var/log/duplicity.log" ]]; then
    TOTAL_DISK_USED="$(df -BM --total 2>/dev/null| awk '/total/ {print $3}' | sed -e 's/M//g')"

    DUPLICITY_VOL_DONE="$(grep -a -oE 'Volume [0-9]{1,6}' /var/log/duplicity.log | grep -a -oE '[0-9]{1,6}' | tail -n 1)"
    if [[ -z "${DUPLICITY_VOL_DONE}" ]]; then
        lerror "Error reading current volume. Please let duplicity finish at least 1 volume."
        exit 1
    fi

    DUPLICITY_RUNNING_SINCE="$(date +%s -d "$(ps -p $(pgrep duplicity) -o lstart=)")"

    CURRENT_EPOCH="$(date +%s)"

    DUPLICITY_RUNNING_MINUTES="$(( ( ${CURRENT_EPOCH} - ${DUPLICITY_RUNNING_SINCE} ) / 60 ))"

    DUPLICITY_MiB_DONE="$(( ${DUPLICITY_VOL_DONE} * ${VOLUME_SIZE} ))"

    DUPLICITY_Mb_DONE="$(( ${DUPLICITY_MiB_DONE} * 8))"

    DUPLICITY_RUNNING_SECONDS="$(( ${DUPLICITY_RUNNING_MINUTES} * 60 ))"

    if [[ "${DUPLICITY_RUNNING_SECONDS}" -eq "0" ]]; then
        lerror "Error reading current volume. Please let duplicity finish at least 1 volume."
        exit 1
    fi

    DUPLICITY_GiB_DONE="$(( ${DUPLICITY_MiB_DONE} / 1024))"

    MiB_LEFT="$(( ${TOTAL_DISK_USED} - ${DUPLICITY_MiB_DONE} ))"

    DUPLICITY_Mbps="$(( ${DUPLICITY_Mb_DONE} / ${DUPLICITY_RUNNING_SECONDS} ))"

    DUPLICITY_MBps="$(( ${DUPLICITY_Mbps} / 8 ))"

    DUPLICITY_MINUTES_TO_COMPLETE="$(( ${MiB_LEFT} / ( ( 1 + ${DUPLICITY_MBps} ) * 60 ) ))"

    DUPLICITY_HOURS_TO_COMPLETE="$(( ${DUPLICITY_MINUTES_TO_COMPLETE} / 60 ))"

    PERC_DONE="$(awk "BEGIN {printf \"%.2f\",(${DUPLICITY_MiB_DONE}/${TOTAL_DISK_USED})*100}")"

    if [[ -n "${TOTAL_DISK_USED}" ]]; then
        lecho "Diskspace used: ${TOTAL_DISK_USED} MiB / $(( ${TOTAL_DISK_USED} / 1024 )) GiB"
    fi

    if [[ -n "${DUPLICITY_VOL_DONE}" ]]; then
        lecho "Duplicity volume: ${DUPLICITY_VOL_DONE}"
    fi

    if [[ -n "${DUPLICITY_MiB_DONE}" ]]; then
        lecho "Amount uploaded: ${DUPLICITY_MiB_DONE} MiB / ${DUPLICITY_GiB_DONE} GiB."
    fi

    if [[ -n ${DUPLICITY_RUNNING_SINCE} ]]; then
        lecho "Duplicity running for ${DUPLICITY_RUNNING_MINUTES} minutes / $(( ${DUPLICITY_RUNNING_MINUTES} / 60 )) hours."

        lecho "Speed: ${DUPLICITY_Mbps} Mbps / ${DUPLICITY_MBps} MBps"
        lecho " "
        lecho "Full backup only:"
        lecho "Estimated ${DUPLICITY_MINUTES_TO_COMPLETE} minutes / ${DUPLICITY_HOURS_TO_COMPLETE} hours to complete"
    fi

    lecho "${PERC_DONE}% done, $(( ${MiB_LEFT} / 1024 )) GiB left to upload of $(( ${TOTAL_DISK_USED} / 1024 )) GiB."

    PERC_DONE_INT="$(echo ${PERC_DONE} | awk -F. '{print $1}')"
    PERC_REMAIN="$(( 100 - ${PERC_DONE_INT} ))"

    echo -n '['
    for i in $(seq 1 ${PERC_DONE_INT}); do 
        echo -n '#'; 
    done 
    for i in $(seq 1 ${PERC_REMAIN}); do 
        echo -n '_'; 
    done
    echo ']'
    
    # clean log if it's larger than 128MiB
    if [[ "$(wc -c /var/log/duplicity.log)" > "134217728" ]]; then
        log "strace log larger than 128MiB, cleaning up."
        echo "Volume ${DUPLICITY_VOL_DONE}" > /var/log/duplicity.log
    fi
fi
