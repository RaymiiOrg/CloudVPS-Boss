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

PATH=/usr/local/bin:$PATH

VERSION="1.0"

TITLE="SwiftRecovery ${VERSION}"
PID="$$"
trap ctrl_c INT

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

wget -O /tmp/swiftbackup.tar.gz http://cdn.duplicity.so/swiftbackup_latest.tar.gz
if [[ $? -ne 0 ]]; then
    lecho "Download of swiftbackup failed. Check wget and network connectivity."
    exit 1
fi

lecho "Swiftupgrade started on $(date)."
pushd /tmp 
tar -xf swiftbackup.tar.gz
if [[ $? -ne 0 ]]; then
    lecho "Extraction of swiftbackup failed."
    exit 1
fi
popd

pushd /tmp/swiftbackup
bash install.sh
if [[ $? -ne 0 ]]; then
    lecho "Upgrade of swiftbackup failed."
    exit 1
fi
popd