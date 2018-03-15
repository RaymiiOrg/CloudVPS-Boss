#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2018 Remy van Elst. (CloudVPS Backup to Object Store Script)
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

VERSION="1.9.17"
TITLE="CloudVPS Boss File Overview ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

if [[ -n "$1" ]]; then
    TIME="$1"
    TIMEOPT="--time $1"
    TIME_MESS="Requested Time: $1"
fi

echo "========================================="
lecho "Start of CloudVPS Boss File Overview"
lecho "Hostname: ${HOSTNAME}"
lecho "$TIME_MESS"
echo "-----------------------------------------"
lecho "duplicity list-current-files --file-prefix=\"${HOSTNAME}.\" --name=\"${HOSTNAME}.\" ${ENCRYPTION_OPTIONS} ${CUSTOM_DUPLICITY_OPTIONS} --allow-source-mismatch --num-retries 100 ${TIMEOPT} ${BACKUP_BACKEND}"
duplicity list-current-files \
    --file-prefix="${HOSTNAME}." \
    --name="${HOSTNAME}." \
    ${ENCRYPTION_OPTIONS} \
    ${CUSTOM_DUPLICITY_OPTIONS} \
    --allow-source-mismatch \
    --num-retries 100 \
    ${TIMEOPT} \
    ${BACKUP_BACKEND} 2>&1 | grep -v -e Warning -e pkg_resources -e oslo
lecho "End of CloudVPS Boss File Overview"
echo "========================================="

