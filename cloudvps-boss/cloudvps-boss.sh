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

VERSION="1.9.12"
TITLE="CloudVPS Boss Backup ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

lecho "${TITLE} started on ${HOSTNAME} at $(date)."

echo
lecho "Running pre-backup scripts from /etc/cloudvps-boss/pre-backup.d/"
for SCRIPT in /etc/cloudvps-boss/pre-backup.d/*; do
    if [[ ! -d "${SCRIPT}" ]]; then
        if [[ -x "${SCRIPT}" ]]; then
            if [[ ! " ${PRE_BACKUP_IGNORE[@]} " =~ " ${SCRIPT} " ]]; then
                log "${SCRIPT}"
                ionice -c2 nice -n19 "${SCRIPT}"
                if [[ $? -ne 0 ]]; then
                    lerror "Pre backup script ${SCRIPT} failed."
                fi
            fi
        fi
    fi
done

echo
lecho "Create full backup if last full backup is older than: ${FULL_IF_OLDER_THAN} and keep at max ${FULL_TO_KEEP} full backups."
lecho "Starting Duplicity"

lecho "duplicity --verbosity 9 --log-file /var/log/duplicity.log --volsize ${VOLUME_SIZE} --tempdir=\"${TEMPDIR}\" --file-prefix=\"${HOSTNAME}.\" --name=\"${HOSTNAME}.\" --exclude-device-files --allow-source-mismatch --num-retries 100 --exclude-filelist=/etc/cloudvps-boss/exclude.conf --full-if-older-than=\"${FULL_IF_OLDER_THAN}\" ${ENCRYPTION_OPTIONS} ${CUSTOM_DUPLICITY_OPTIONS} / ${BACKUP_BACKEND}"

OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_OUTPUT=$(duplicity \
    --verbosity 4 \
    --log-file /var/log/duplicity.log \
    --volsize=${VOLUME_SIZE} \
    --tempdir="${TEMPDIR}" \
    --file-prefix="${HOSTNAME}." \
    --name="${HOSTNAME}." \
    --exclude-device-files \
    --allow-source-mismatch \
    --num-retries 100 \
    --exclude-filelist=/etc/cloudvps-boss/exclude.conf \
    --full-if-older-than="${FULL_IF_OLDER_THAN}" \
    ${ENCRYPTION_OPTIONS} \
    ${CUSTOM_DUPLICITY_OPTIONS} \
    / \
    ${BACKUP_BACKEND} 2>&1 | grep -v -e Warning -e pkg_resources -e oslo -e tar -e attr -e kwargs| sed -n -e '/--------------/,/--------------/ p')

if [[ $? -ne 0 ]]; then
    for line in ${DUPLICITY_OUTPUT}; do
            lerror ${line}
    done
    lerror "CloudVPS Boss Backup to Object Store FAILED!. Please check server ${HOSTNAME}."
    lerror "Running post-fail-backup scripts from /etc/cloudvps-boss/post-fail-backup.d/"
    for SCRIPT in /etc/cloudvps-boss/post-fail-backup.d/*; do
        if [[ ! -d "${SCRIPT}" ]]; then
            if [[ -x "${SCRIPT}" ]]; then
                if [[ ! " ${POST_FAIL_BACKUP_IGNORE[@]} " =~ " ${SCRIPT} " ]]; then
                    "${SCRIPT}" || lerror "Post fail backup script ${SCRIPT} failed."
                fi
            fi
        fi
    done
    exit 1
fi

for line in ${DUPLICITY_OUTPUT}; do
        lecho "${line}"
done
IFS="${OLD_IFS}"

echo 
lecho "CloudVPS Boss Cleanup ${VERSION} started on $(date). Removing all but ${FULL_TO_KEEP} full backups."
lecho "duplicity --verbosity 9 --log-file /var/log/duplicity.log --file-prefix=\"${HOSTNAME}.\" --name=\"${HOSTNAME}.\" remove-all-but-n-full \"${FULL_TO_KEEP}\" ${ENCRYPTION_OPTIONS} --force  ${BACKUP_BACKEND}"

OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_CLEANUP_OUTPUT=$(duplicity \
    --verbosity 4 \
    --log-file /var/log/duplicity.log \
    --file-prefix="${HOSTNAME}." \
    --name="${HOSTNAME}." \
    remove-all-but-n-full \
    "${FULL_TO_KEEP}" \
    ${ENCRYPTION_OPTIONS} \
    --force \
    ${BACKUP_BACKEND} 2>&1 | grep -v -e Warning -e pkg_resources -e oslo -e attr -e kwargs)
if [[ $? -ne 0 ]]; then
    for line in ${DUPLICITY_CLEANUP_OUTPUT}; do
            lerror ${line}
    done
    lerror "CloudVPS Boss Cleanup FAILED!. Please check server ${HOSTNAME}." 
fi

for line in ${DUPLICITY_CLEANUP_OUTPUT}; do
        lecho "cleanup: ${line}"
done
IFS="${OLD_IFS}"

echo
lecho "Running post-backup scripts from /etc/cloudvps-boss/post-backup.d/"
for SCRIPT in /etc/cloudvps-boss/post-backup.d/*; do
    if [[ ! -d "${SCRIPT}" ]]; then
        if [[ -x "${SCRIPT}" ]]; then
            if [[ ! " ${POST_BACKUP_IGNORE[@]} " =~ " ${SCRIPT} " ]]; then
                "${SCRIPT}" || lerror "Post backup script ${SCRIPT} failed."
            fi
        fi
    fi
done

echo
lecho "CloudVPS Boss ${VERSION} ended on $(date)."
