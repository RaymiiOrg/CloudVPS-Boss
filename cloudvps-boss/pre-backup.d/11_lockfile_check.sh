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
TITLE="CloudVPS Boss Lockfile Check ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

DUPLICITY_LOCKFILE="$(find /root/.cache/duplicity -iname '*.lock' 2>&1 | head -n 1)"

greater_than_24hour_mail() {
    for COMMAND in "mail"; do
        command_exists "${COMMAND}"
    done

    mail -s "[CLOUDVPS BOSS] ${HOSTNAME}/$(curl -s http://ip.raymii.org): Other backup job still running, more than 24 hours." "${recipient}" <<MAIL

Dear user,

This is a message to inform you that your backup to the CloudVPS
Object Store has not succeeded on date: $(date) (server date/time).

This is because the backup lockfile still exists.

The backupscript has noticed that the last initiated job was still running after 24 hours. This is unusual behaviour and could lead to hanging backup processes.

Should this process hang for 24 hours as well, you will receive this message again, then CloudVPS Boss needs investigation to see what is causing the issues. Please contact support@cloudvps.com and forward this email.

Your files have not been backupped during this session.

This is server $(curl -s http://ip.raymii.org). You are using CloudVPS Boss ${VERSION}
to backup files to the CloudVPS Object Store.

Kind regards,
CloudVPS Boss
MAIL
}

send_greater_than_24hour_mail() {
    if [[ -f "/etc/cloudvps-boss/email.conf" ]]; then
        while read recipient; do
             greater_than_24hour_mail
        done < /etc/cloudvps-boss/email.conf
    else
        lerror "No email file found. Not mailing"
    fi
}

less_than_24hour_mail() {
    for COMMAND in "mail"; do
        command_exists "${COMMAND}"
    done

    mail -s "[CLOUDVPS BOSS] ${HOSTNAME}/$(curl -s http://ip.raymii.org): Other backupjob still running, less than 24 hours." "${recipient}" <<MAIL

Dear user,

This is a message to inform you that your backup to the CloudVPS
Object Store has not succeeded on date: $(date) (server date/time).

This is because the backup lockfile still exists.

The script has investigated this problem and has stated that the current running backup process has not passed the 24 hour run limit yet.

Therefore this backup job will not continue to make sure that the current process can succeed without errors.

Currently, there is no intervention needed from your side, CloudVPS Boss has already chosen the appropriate solution at this point.

Your files have not been backupped during this session.

This is server $(curl -s http://ip.raymii.org). You are using CloudVPS Boss ${VERSION}
to backup files to the CloudVPS Object Store.

Kind regards,
CloudVPS Boss
MAIL
}

send_less_than_24hour_mail() {
    if [[ -f "/etc/cloudvps-boss/email.conf" ]]; then
        while read recipient; do
             less_than_24hour_mail
        done < /etc/cloudvps-boss/email.conf
    else
        lerror "No email file found. Not mailing"
    fi
}

if [[ ! -z "${DUPLICITY_LOCKFILE}" ]]; then
    if [[ -f "${DUPLICITY_LOCKFILE}" ]]; then
        lecho "Duplicity Lockfile found"
        FILETIME="$(stat -c %Y ${DUPLICITY_LOCKFILE})"
        CURRTIME="$(date +%s)"
        TIMEDIFF="$(( (CURRTIME - FILETIME) / 84600))"
        if [[ ${TIMEDIFF} != 0 ]]; then
            lecho "Lockfile is older thay 24 hours."
            pgrep duplicity
            if [[ $? -ne 0 ]]; then
                lecho "Cannot find running duplicity process. Removing lockfile"
                rm "${DUPLICITY_LOCKFILE}"
                if [[ $? -ne 0 ]]; then
                    lerror "Cannot remove lockfile"
                fi
            else
                echo "Duplicity is still running, longer than 24 hours."
                send_greater_than_24hour_mail
            fi
        else
            lecho "Lockfile exists but is not older than 24 hours."
            pgrep duplicity
            if [[ $? -ne 0 ]]; then
                lecho "Cannot find running duplicity process. Removing lockfile"
                rm "${DUPLICITY_LOCKFILE}"
                if [[ $? -ne 0 ]]; then
                    lerror "Cannot remove lockfile"
                fi
            else
                echo "Duplicity is still running. Seems OK."
                touch /etc/cloudvps-boss/status/24h
                send_less_than_24hour_mail
            fi
        fi
    else
        lecho "Lockfile variable set but not a file. Lockfile var contents: ${DUPLICITY_LOCKFILE}."
    fi
else
    log "Lockfile not found."
fi

