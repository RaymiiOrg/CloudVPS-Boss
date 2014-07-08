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
# CloudVPS, hereby disclaims all copyright interest in the program 
# `SwiftBackup' written by Remy van Elst.

set -o pipefail

lecho() {
    logger -t "swiftbackup" -- "$1"
    echo "# $1"
}

lerror() {
    logger -s -t "swiftbackup" -- "ERROR - $1"
    echo "$1" 1>&2
}

remove_file() {
    if [[ -f "$1" ]]; then
        lecho "Removing file $1"
        rm "$1"
        if [[ "$?" != 0 ]]; then
            lerror "Could not remove file $1"
        fi
    fi
}

remove_folder() {
    if [[ -d "$1" ]]; then
        lecho "Removing folder $1"
        rm -r "$1"
        if [[ "$?" != 0 ]]; then
            lerror "Could not remove folder $1"
        fi
    fi
}

remove_symlink() {
    if [[ -h "$1" ]]; then
        lecho "Removing symlink $1"
        rm "$1"
        if [[ "$?" != 0 ]]; then
            lerror "Could not remove symlink $1"
        fi
    fi
}

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

read -p "Would you like to completely remove SwiftBackup? Your backups will NOT be removed. [y/N]? " choice



if [[ "${choice}" = "y" ]]; then
    lecho "Completely removing all of SwiftBackup"
    for FILE in "/etc/cron.d/swiftbackup"; do
        remove_file "${FILE}"
    done
    for FOLDER in "/etc/swiftbackup/"; do
        remove_folder "${FOLDER}"
    done
    for SYMLINK in "/usr/local/bin/swiftbackup" "/usr/local/bin/swiftrecovery" "/usr/local/bin/swiftstats"; do
        remove_symlink "${SYMLINK}"
    done
    for PIP in "python-swiftclient" "python-keystoneclient"; do
        lecho "Uninstalling ${PIP} with pip."
        echo "y\n" | pip -q uninstall "${PIP}" 2>&1 > /dev/null
    done
    exit
fi

lecho "Choice was not 'y'. Not removing anything. Exiting."
