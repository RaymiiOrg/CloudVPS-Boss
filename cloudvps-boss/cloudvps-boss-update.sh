#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2015 CloudVPS. (CloudVPS Backup to Object Store Script)
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

VERSION="1.8"
TITLE="CloudVPS Boss Upgrade ${VERSION}"

DL_SRV="https://2162bb74000a471eb2839a7f1648771a.objectstore.eu/duplicity-cdn/"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh


failed_mail() {
    for COMMAND in "mail"; do
        command_exists "${COMMAND}"
    done

    mail -s "[CLOUDVPS BOSS] Update failed on ${HOSTNAME}/$(curl -s http://ip.raymii.org)." "${recipient}" <<MAIL

Dear user,

This is a message to inform you that the CloudVPS Boss automatic
upgrade has not succeeded on date: $(date) (server date/time).

You are using version ${VERSION}. CloudVPS Boss updates itself
every sunday, and this time it has failed. Please investigate 
the logging on this server to find out why.

If you receive this email once, it might just be a one-off error. 

If you receive this email more than once (for example, every week)
then this server requires investigation. If so, please forward this email to support@cloudvps.com so we can check it for you.

This is server $(curl -s http://ip.raymii.org). You are using CloudVPS Boss ${VERSION}
to backup files to the CloudVPS Object Store.

Kind regards,
CloudVPS Boss
MAIL
}

send_failed_mail() {
    if [[ -f "/etc/cloudvps-boss/email.conf" ]]; then
        while read recipient; do
             failed_mail
        done < /etc/cloudvps-boss/email.conf
    else
        lerror "No email file found. Not mailing"
    fi
}

lecho "${TITLE} started on ${HOSTNAME} at $(date)."

pushd /tmp 

if [[ -f "/tmp/cloudvps-boss.tar.gz" ]]; then
    lecho "Removing old update file from /tmp/cloudvps-boss.tar.gz"
    rm -rf /tmp/cloudvps-boss.tar.gz
fi

if [[ -d "/tmp/cloudvps-boss" ]]; then
    lecho "Removing old update folder from /tmp/cloudvps-boss"
    rm -rf /tmp/cloudvps-boss
fi

lecho "Downloading CloudVPS Boss from ${DL_SRV}cloudvps-boss_latest.tar.gz"
get_file "/tmp/cloudvps-boss.tar.gz" "${DL_SRV}cloudvps-boss_latest.tar.gz"
if [[ $? -ne 0 ]]; then
    lecho "Download of cloudvps-boss failed. Check firewall and network connectivity."
    exit 1
fi

tar -xf cloudvps-boss.tar.gz
if [[ $? -ne 0 ]]; then
    lecho "Extraction of cloudvps-boss in /tmp failed."
    exit 1
fi
popd

pushd /tmp/cloudvps-boss
bash install.sh
if [[ $? -ne 0 ]]; then
    lecho "Upgrade of cloudvps-boss failed. Emailing user."
    send_failed_mail
    rm -rf /tmp/cloudvps-boss
    exit 1
fi
popd

lecho "${TITLE} ended on ${HOSTNAME} at $(date)."
