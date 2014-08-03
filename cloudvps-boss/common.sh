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

# This file contains common functions used by CloudVPS Boss

set -o pipefail

if [[ ${DEBUG} == "1" ]]; then
    set -x
fi

trap ctrl_c INT

lecho() {
    logger -t "cloudvps-boss" -- "$1"
    echo "# $1"
}

log() {
    logger -t "cloudvps-boss" -- "$1"
}

lerror() {
    logger -t "cloudvps-boss" -- "ERROR - $1"
    echo "$1" 1>&2
}

PATH=/usr/local/bin:$PATH
PID="$$"
# Do not edit. Workaround for an openstack pbr bug. If not set, everything swift will fail miserably with errors like; Exception: Versioning for this project requires either an sdist tarball, or access to an upstream git repository. Are you sure that git is installed?

export PBR_VERSION="0.10.0"
PBR_VERSION="0.10.0"

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

if [[ ! -f "/etc/cloudvps-boss/auth.conf" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/auth.conf."
    exit 1
fi
if [[ ! -f "/etc/cloudvps-boss/backup.conf" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/backup.conf."
    exit 1
fi

source /etc/cloudvps-boss/auth.conf
source /etc/cloudvps-boss/backup.conf

command_exists() {
    command -v "$1" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        lerror "I require $1 but it's not installed. Aborting."
        exit 1
    fi
}

fake_progress() {
    if [[ ! -z "$1" ]]; then
        if [[ $(pgrep "$1") ]]; then
                spin='-\|/.'
                i=$(( (i+1) %5 ))
                printf "\r  ${spin:$i:1}"
                sleep 0.1
                fake_progress "$1"
        fi
    fi
}

progress_bar() {
    if [[ "${RUNNINGFROMCRON}" -ne 1 ]]; then
            echo "This spinner does not represent any progress. It just shows you we're still running."
            echo
            fake_progress duplicity &
    fi
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

json_parse() {
    sed -e 's/\\\\\//\//g' -e 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed -e 's/\"\:\"/\|/g' -e 's/[\,]/ /g' -e 's/\"//g'
}

get_hostname() {
    
    HOSTNAME="$(curl -m 3 -s http://169.254.169.254/openstack/latest/meta_data.json | json_parse | awk '/uuid/ {print $2}')"
    if [[ -z "${HOSTNAME}" ]]; then
        if [[ -f "/var/firstboot/settings" ]]; then
            HOSTNAME="$(awk -F= '/hostname/ {print $2}' /var/firstboot/settings)"
        else
            HOSTNAME="$(uname -n)"
        fi
    fi

    echo "${HOSTNAME}"
}

ctrl_c() {
    lerror "SIGINT received. Exiting."
    exit 1
}

check_choice() {
    if [[ -z "${!1}" ]]; then
        dialog --title "${TITLE} - Error" --msgbox "${2} must be set. Aborting" 5 50
        exit 1
    fi
}

if [[ ! -d "/etc/cloudvps-boss/status/${HOSTNAME}" ]]; then
    mkdir -p "/etc/cloudvps-boss/status/${HOSTNAME}"
    if [[ $? -ne 0 ]]; then
        lerror "Cannot create status folder"
        exit 1
    fi
fi

for COMMAND in "curl" "wget" "awk" "sed" "grep" "tar" "gzip" "which" "openssl" "nice" "ionice"; do
    command_exists "${COMMAND}"
done

ACTUAL_HOSTNAME="$(get_hostname)"
logger -t "cloudvps-boss" -- "Configured hostname is ${HOSTNAME}."
logger -t "cloudvps-boss" -- "Actual hostname is ${ACTUAL_HOSTNAME}."

echo
logger -t "cloudvps-boss" -- "${TITLE} started on ${HOSTNAME} at $(date)."
