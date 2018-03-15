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
TITLE="CloudVPS Boss PostgreSQL Backup ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

command -v psql >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    PSQLD=1
fi

command -v pg_dump >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    PSQLD=1
fi

command -v pg_dumpall >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    PSQLD=1
fi

if [[ "${PSQLD}" == 1 ]]; then
    log "psql, pg_dump or pg_dumpall not found, not dumping postgresql."
    exit
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
su postgres -c "ionice -c2 nice -n19 pg_dumpall -g | gzip > /var/backups/sql/pg_global_data.sql.gz"
if [[ $? -ne 0 ]]; then
    lerror "Failed dumping postgres globals."
else
    lecho "Dumped globals"
fi
