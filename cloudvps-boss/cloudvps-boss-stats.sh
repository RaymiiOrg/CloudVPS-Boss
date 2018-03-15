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
TITLE="CloudVPS Boss Stats ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh


USED="$(swift stat --lh ${CONTAINER_NAME} 2>&1 | awk '/Bytes/ { print $2}' | grep -v -e Warning -e pkg_resources -e oslo)"

echo "========================================="
lecho "Start of CloudVPS Boss Status ${VERSION}"
lecho "Hostname: ${HOSTNAME}"
lecho "External IP: $(curl -s http://ip.cloudvps.nl)"
lecho "Username: ${SWIFT_USERNAME}"
lecho "Storage used: ${USED}"
lecho "Full backups to keep: ${FULL_TO_KEEP}"
lecho "Create full backup if last full backup is older than: ${FULL_IF_OLDER_THAN}"
echo "-----------------------------------------"
lecho "Duplicity collection status:"
OLD_IFS="${IFS}"
IFS=$'\n'
DUPLICITY_STATS="$(
    duplicity collection-status \
    --file-prefix="${HOSTNAME}." \
    --name="${HOSTNAME}." \
    ${CUSTOM_DUPLICITY_OPTIONS} \
    ${BACKUP_BACKEND} 2>&1 | grep -v -e Warning -e pkg_resources -e oslo -e tar -e attr -e kwargs)"
for line in ${DUPLICITY_STATS}; do
        lecho "${line}"
done
IFS="${OLD_IFS}"
lecho "End of CloudVPS Boss Status"
echo "========================================="

