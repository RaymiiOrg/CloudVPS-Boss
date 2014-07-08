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

command_exists() {
    command -v "$1" >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        lerror "I require $1 but it's not installed. Aborting."
        exit 1
    fi
}

if [[ "${EUID}" -ne 0 ]]; then
   echo "This script must be run as root." 1>&2
   exit 1
fi

if [[ ! -d "/var/backups/sql" ]]; then
    mkdir -p "/var/backups/sql"
fi

chmod 777 "/var/backups/sql"

for COMMAND in "psql" "pg_dump" "pg_dumpall"; do
    command_exists "${COMMAND}"
done

id postgres >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    lerror "System user postgres not found. Not backing up postgresql databases." 
    exit 1
fi

cd /tmp

DATABASES=$(su - postgres -c "psql -l -t | cut -d'|' -f1 | sed -e 's/ //g' -e '/^$/d' | grep -v 'template'")
if [[ $? -ne 0 ]]; then
    lerror "Could not retreive postgres databases."
    exit 1
fi

for DB in ${DATABASES}; do
    lecho "Dumping database ${DB} to /var/backups/sql/${DB}.psql.gz"
    su postgres -c "pg_dump ${DB} | gzip > /var/backups/sql/${DB}.psql.gz"
    if [[ $? -ne 0 ]]; then
        lerror "Failed dumping postgres database ${DB}"
    else
        lecho "Dumped ${DB}"
    fi
done

lecho "Dumping pg globals (roles and such, pg_dumpall -g)"
su postgres -c "pg_dumpall -g | gzip > /var/backups/sql/pg_global_data.sql.gz"
if [[ $? -ne 0 ]]; then
    lerror "Failed dumping postgres globals."
else
    lecho "Dumped globals"
fi
