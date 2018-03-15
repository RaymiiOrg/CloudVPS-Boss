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
TITLE="CloudVPS Boss Failure Notify ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

if [[ -f "/etc/cloudvps-boss/status/24h" ]]; then
    lecho "24 hour backup file found. Not sending email, removing file."
    rm "/etc/cloudvps-boss/status/24h"
    exit 0
fi

for COMMAND in "mail"; do
    command_exists "${COMMAND}"
done

getlogging() {
    if [[ -f /var/log/duplicity.log ]]; then
        lecho "200 most recent lines in /var/log/duplicity.log:"
        tail -n 200  /var/log/duplicity.log

    else
        if [[ -f "/var/log/messages" ]]; then
            lecho "10 most recent lines with cloudvps-boss ERROR in /var/log/messages:"
            grep "cloudvps-boss: ERROR" /var/log/messages | tail -n 10
        fi
        if [[ -f "/var/log/syslog" ]]; then
            lecho "10 most recent lines with cloudvps-boss ERROR in /var/log/syslog:"
            grep "cloudvps-boss: ERROR" /var/log/syslog | tail -n 10
        fi
    fi

}

errormail() {

    mail -s "[CLOUDVPS BOSS] ${HOSTNAME}/$(curl -s http://ip.raymii.org): Critical error occurred during the backup!" "${recipient}" <<MAIL

Dear user,

This is a message to inform you that your backup to the CloudVPS
Object Store has not succeeded on date: $(date) (server date/time).

Here is some information:

===== BEGIN CLOUDVPS BOSS STATS =====
$(cloudvps-boss-stats)
===== END CLOUDVPS BOSS STATS =====

===== BEGIN CLOUDVPS BOSS ERROR LOG =====
$(getlogging)
===== END CLOUDVPS BOSS ERROR LOG =====

This is server $(curl -s http://ip.raymii.org). You are using CloudVPS Boss ${VERSION}
to backup files to the CloudVPS Object Store.

Your files have not been backupped at this time. Please investigate this issue.

IMPORTANT: YOUR FILES HAVE NOT BEEN BACKED UP. PLEASE INVESTIGAE THIS ISSUE.

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
