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

VERSION="1.2"

TITLE="CloudVPS Boss Uninstall ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

read -p "Would you like to completely remove CloudVPS Boss? Your backups will NOT be removed. [y/N]? " choice

if [[ "${choice}" = "y" ]]; then
    lecho "Completely removing all of CloudVPS Boss"
    for FILE in "/etc/cron.d/cloudvps-boss"; do
        remove_file "${FILE}"
    done
    for SYMLINK in "/usr/local/bin/cloudvps-boss" "/usr/local/bin/cloudvps-boss-restore" "/usr/local/bin/cloudvps-boss-stats"; do
        remove_symlink "${SYMLINK}"
    done
    for PIP in "python-swiftclient" "python-keystoneclient"; do
        lecho "Uninstalling ${PIP} with pip."
        echo "y\n" | pip -q uninstall "${PIP}" 2>&1 > /dev/null
    done
    for FOLDER in "/usr/local/cloudvps-boss"  "/etc/cloudvps-boss/"; do
        remove_folder "${FOLDER}"
    done
    cd
    exit
fi

lecho "Choice was not 'y'. Not removing anything. Exiting."