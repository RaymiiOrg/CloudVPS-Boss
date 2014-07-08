#!/bin/bash
# SwiftBackup - Duplicity wrapper to back up to OpenStack Swift, Object 
# Store. Copyright (C) 2014 Remy van Elst, https://raymii.org
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
# CloudVPS, hereby disclaims all copyright interest in the program 
# `SwiftBackup' written by Remy van Elst.

set -o pipefail

PATH=/usr/local/bin:$PATH

VERSION="1.0"

lecho() {
    logger -t "swiftbackup" -- "$1"
    echo "# $1"
}

lerror() {
    logger -s -t "swiftbackup" -- "ERROR - $1"
    echo "$1" 1>&2
}

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

if [[ ! -f "/etc/swiftbackup/auth.conf" ]]; then
    lerror "Cannot find /etc/swiftbackup/auth.conf."
    exit 1
fi
if [[ ! -f "/etc/swiftbackup/backup.conf" ]]; then
    lerror "Cannot find /etc/swiftbackup/backup.conf."
    exit 1
fi

source /etc/swiftbackup/auth.conf
source /etc/swiftbackup/backup.conf

echo
lecho "Running pre-backup scripts from /etc/swiftbackup/pre-backup.d/"
find /etc/swiftbackup/pre-backup.d/ -maxdepth 1 -type f -perm +111 -exec {} \; 2>&1
if [[ $? -ne 0 ]]; then
    # fedora > 19 has newer find.
    find /etc/swiftbackup/pre-backup.d/ -maxdepth 1 -type f -perm /111 -exec {} \;
fi
    
echo
lecho "SwiftBackup ${VERSION} started on $(date)."
lecho "Full if last full is older than: ${FULL_IF_OLDER_THAN} and keep at max ${FULL_TO_KEEP} full backups."

OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_OUTPUT=$(duplicity \
    --no-encryption \
    --asynchronous-upload \
    --file-prefix="${HOSTNAME}." \
    --exclude-device-files \
    --exclude-globbing-filelist /etc/swiftbackup/exclude.conf \
    --full-if-older-than "${FULL_IF_OLDER_THAN}" \
    / \
    swift://cloudvps-duplicity-backup 2>&1 | grep -v  -e UserWarning -e pkg_resources)

if [[ $? -ne 0 ]]; then
    for line in ${DUPLICITY_OUTPUT}; do
            lerror ${line}
    done
    lerror "SwiftBackup to Object Store FAILED!. Please check server $(uname -n)."
    lerror "Running post-fail-backup scripts from /etc/swiftbackup/post-fail-backup.d/"
    find /etc/swiftbackup/post-fail-backup.d/ -maxdepth 1 -type f -perm +111 -exec {} \; 2>&1
    if [[ $? -ne 0 ]]; then
        # fedora > 19 has newer find.
        find /etc/swiftbackup/post-fail-backup.d/ -maxdepth 1 -type f -perm /111 -exec {} \;
    fi
    exit 1
fi

for line in ${DUPLICITY_OUTPUT}; do
        lecho ${line}
done
IFS="${OLD_IFS}"

echo 
lecho "SwiftCleanup ${VERSION} started on $(date). Removing all but ${FULL_TO_KEEP} full backups."

OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_CLEANUP_OUTPUT=$(duplicity \
    --no-encryption \
    --file-prefix="${HOSTNAME}." \
    remove-all-but-n-full \
    "${FULL_TO_KEEP}" \
    --force \
    swift://cloudvps-duplicity-backup 2>&1 | grep -v  -e UserWarning -e pkg_resources)
if [[ $? -ne 0 ]]; then
    for line in ${DUPLICITY_CLEANUP_OUTPUT}; do
            lerror ${line}
    done
    lerror "SwiftCleanup FAILED!. Please check server ${HOSTNAME}." 
    lerror "Running post-fail-backup scripts from /etc/swiftbackup/post-fail-backup.d/"
    find /etc/swiftbackup/post-fail-backup.d/ -maxdepth 1 -type f -perm +111 -exec {} \; 2>&1
    if [[ $? -ne 0 ]]; then
        #fedora > 19 has newer find.
        find /etc/swiftbackup/post-fail-backup.d/ -maxdepth 1 -type f -perm /111 -exec {} \;
    fi
    exit 1
fi

for line in ${DUPLICITY_CLEANUP_OUTPUT}; do
        lecho ${line}
done
IFS="${OLD_IFS}"

echo
lecho "Running post-backup scripts from /etc/swiftbackup/post-backup.d/"
find /etc/swiftbackup/post-backup.d/ -maxdepth 1 -type f -perm +111 -exec {} \; 2>&1
if [[ $? -ne 0 ]]; then
    # fedora > 19 has newer find.
    find /etc/swiftbackup/post-backup.d/ -maxdepth 1 -type f -perm /111 -exec {} \;
fi

echo
lecho "SwiftBackup ${VERSION} ended on $(date)."
