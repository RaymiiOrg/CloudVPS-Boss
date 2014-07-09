#!/bin/bash
# SwiftBackup - Duplicity wrapper to back up to OpenStack Swift, Object 
# Store. Copyright (C) 2014 CloudVPS. 
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

set -o pipefail

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

lecho() {
    logger -t "swiftbackup" -- "[swiftbackup] - $1"
    echo "# $1"
}

lerror() {
    logger -s -t "swiftbackup" -- "[swiftbackup] ERROR - $1"
    echo "$1" 1>&2
}

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

USED="$(swift stat --lh cloudvps-duplicity-backup 2>&1 | awk '/Bytes/ { print $2}' | grep -v  -e UserWarning -e pkg_resources)"

echo "========================================="
lecho "Start of SwiftBackup Status"
lecho "Hostname: ${HOSTNAME}"
lecho "Username: ${SWIFT_USERNAME}"
lecho "Storage used: ${USED}"
lecho "Full backups to keep: ${FULL_TO_KEEP}"
lecho "Create full backup if last full backup is older than: ${FULL_IF_OLDER_THAN}"
echo "-----------------------------------------"
lecho "Duplicity collection status:"
OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_STATS="$(duplicity collection-status --file-prefix="${HOSTNAME}." --no-encryption swift://cloudvps-duplicity-backup 2>&1 | grep -v -e UserWarning -e pkg_resources)"
for line in ${DUPLICITY_STATS}; do
        lecho ${line}
done
IFS="${OLD_IFS}"
lecho "End of SwiftBackup Status"
echo "========================================="

