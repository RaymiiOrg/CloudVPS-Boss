#!/bin/bash
# CloudVPS Boss - Duplicity wrapper to back up to OpenStack Swift
# Copyright (C) 2017 Remy van Elst. (CloudVPS Backup to Object Store Script)
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

VERSION="1.9.12"
TITLE="CloudVPS Boss Upgrade ${VERSION}"

DL_SRV="https://2162bb74000a471eb2839a7f1648771a.objectstore.eu/duplicity-cdn/"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

lecho "${TITLE} started on ${HOSTNAME} at $(date)."

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

if [[ ! -d "/root/.cloudvps-boss" ]]; then
    mkdir -p "/root/.cloudvps-boss"
fi

pushd /root/.cloudvps-boss

if [[ -f "/root/.cloudvps-boss/cloudvps-boss.tar.gz" ]]; then
    lecho "Removing old update file from /root/.cloudvps-boss/cloudvps-boss.tar.gz"
    rm -rf /root/.cloudvps-boss/cloudvps-boss.tar.gz
fi

if [[ -d "/root/.cloudvps-boss/cloudvps-boss" ]]; then
    lecho "Removing old update folder from /root/.cloudvps-boss/cloudvps-boss"
    rm -rf /root/.cloudvps-boss/cloudvps-boss
fi

if [[ -f "/etc/cloudvps-boss/pre-backup.d/11_lockfile_check.sh" ]]; then
    lecho "Removing the old lockfile-check script at /etc/cloudvps-boss/pre-backup.d/11_lockfile_check.sh - Cleanup for consistency."
    rm -f /etc/cloudvps-boss/pre-backup.d/11_lockfile_check.sh
fi

if [[ -f "/etc/cloudvps-boss/pre-backup.d/15-mysql_backup.sh" ]]; then
    lecho "Removing the old 15-mysql_backup script at /etc/cloudvps-boss/pre-backup.d/15-mysql_backup.sh - Cleanup for consistency."
    rm -f /etc/cloudvps-boss/pre-backup.d/15-mysql_backup.sh
fi

if [[ -f "/etc/cloudvps-boss/pre-backup.d/15-postgresql_backup.sh" ]]; then
    lecho "Removing the old 15-mysql_backup script at /etc/cloudvps-boss/pre-backup.d/15-postgresql_backup - Cleanup for consistency."
    rm -f /etc/cloudvps-boss/pre-backup.d/15-postgresql_backup.sh
fi



lecho "Downloading CloudVPS Boss from ${DL_SRV}cloudvps-boss_latest.tar.gz"
get_file "/root/.cloudvps-boss/cloudvps-boss.tar.gz" "${DL_SRV}cloudvps-boss_latest.tar.gz"
if [[ $? -ne 0 ]]; then
    lecho "Download of cloudvps-boss failed. Check firewall and network connectivity."
    exit 1
fi

tar -xf cloudvps-boss.tar.gz
if [[ $? -ne 0 ]]; then
    lecho "Extraction of cloudvps-boss in /root/.cloudvps-boss failed."
    exit 1
fi
popd

pushd /root/.cloudvps-boss/cloudvps-boss
bash install.sh
