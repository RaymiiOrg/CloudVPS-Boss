#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2017 Remy van Elst. (CloudVPS Backup to Object Store Script)
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

VERSION="1.9.13"
TITLE="CloudVPS Boss Completed Status Upload ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

touch "/etc/cloudvps-boss/status/${HOSTNAME}/completed"
if [[ $? -ne 0 ]]; then
    lerror "Cannot update status"
    exit 1
fi

OLD_IFS="${IFS}"
IFS=$'\n'
SWIFTTOUCH=$(swift upload ${CONTAINER_NAME} "/etc/cloudvps-boss/status/${HOSTNAME}/completed" --object-name "status/${HOSTNAME}/completed" 2>&1 | grep -v -e Warning -e pkg_resources -e oslo)
if [[ $? -ne 0 ]]; then
    lerror "Could not upload completed status"
    for line in ${SWIFTTOUCH}; do
        lerror ${line}
    done
fi
IFS="${OLD_IFS}"

lecho "${TITLE} ended on ${HOSTNAME} at $(date)."
