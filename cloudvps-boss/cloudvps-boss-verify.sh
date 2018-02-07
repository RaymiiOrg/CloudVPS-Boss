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
TITLE="CloudVPS Boss Backup Verify ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

lecho "${TITLE} started on ${HOSTNAME} at $(date)."

lecho "duplicity verify --volsize ${VOLUME_SIZE} --tempdir=\"${TEMPDIR}\" --file-prefix=\"${HOSTNAME}.\" --name=\"${HOSTNAME}.\" --exclude-device-files --allow-source-mismatch --num-retries 100 --exclude-filelist=/etc/cloudvps-boss/exclude.conf ${ENCRYPTION_OPTIONS} ${BACKUP_BACKEND} /"

OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_OUTPUT=$(duplicity \
    verify \
    --volsize=${VOLUME_SIZE} \
    --tempdir="${TEMPDIR}" \
    --file-prefix="${HOSTNAME}." \
    --name="${HOSTNAME}." \
    --exclude-device-files \
    --allow-source-mismatch \
    --num-retries 100 \
    --exclude-filelist=/etc/cloudvps-boss/exclude.conf \
    ${ENCRYPTION_OPTIONS} \
    ${BACKUP_BACKEND} \
    / 2>&1 | grep -v  -e Warning -e pkg_resources -e oslo)

if [[ $? -ne 0 ]]; then
    for line in ${DUPLICITY_OUTPUT}; do
            lerror ${line}
    done
    lerror "CloudVPS Boss Verify FAILED!. Please check server ${HOSTNAME}."
fi

for line in ${DUPLICITY_OUTPUT}; do
        lecho "${line}"
done
IFS="${OLD_IFS}"

echo
lecho "CloudVPS Boss Verify ${VERSION} ended on $(date)."
