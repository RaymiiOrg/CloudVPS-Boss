#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2014 CloudVPS. (CloudVPS Backup to Object Store Script)
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

TITLE="CloudVPS Boss Failure Notify ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

for COMMAND in "mail"; do
    command_exists "${COMMAND}"
done

errormail() {

    mail -s "[CLOUDVPS BOSS] Critical error occurred during the backup!" "${recipient}" <<MAIL

Dear user,

This is a message to inform you that your backup to the CloudVPS 
Object Store has not succeeded on date: $(date) (server date/time).

Here is some information:

===== BEGIN CLOUDVPS BOSS STATS =====
$(cloudvps-boss-stats)
===== END CLOUDVPS BOSS STATS =====

This is server $(curl -s http://ip.mtak.nl). You are using CloudVPS Boss
to backup files to the Object Store.

Your files have not been backupped at this time.

Kind regards,
CloudVPS Boss
MAIL
}

if [[ -f "/etc/cloudvps-boss/email.conf" ]]; then
    while read recipient; do
         errormail
    done < /etc/cloudvps-boss/email.conf
else
    lerror "No email file found. Not mailing"
fi
