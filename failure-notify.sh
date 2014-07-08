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

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

errormail() {

    mail -s "[SWIFTBACKUP] Critical error occurred during the backup!" "${recipient}" <<MAIL

Dear user,

This is a message to inform you that your backup has not succeeded.

Here is some information:

$(swiftstats)

This is server $(curl ip.mtak.nl). You are using the SwiftBackup script 
to backup files to the Object Store.

Your files have not been backupped at this time.

Kind regards,
Swiftbackup
MAIL
}

if [[ -f "$(which mail)" ]]; then
    if [[ -f "/etc/swiftbackup/email.conf" ]]; then
        while read recipient; do
             errormail
        done < /etc/swiftbackup/email.conf
    else
        lerror "No email file found. Not mailing"
    fi
else
    lerror "No mail program found."
fi
