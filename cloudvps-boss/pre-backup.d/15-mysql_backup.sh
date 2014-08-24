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


VERSION="1.4"

TITLE="CloudVPS Boss MySQL Backup ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

command -v mysql >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    MYSQLD=1
fi

command -v mysqldump >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
    MYSQLD=1
fi

if [[ "${MYSQLD}" == 1 ]]; then
    log "mysql or mysqldump not found, not dumping mysql."
    exit
fi


if [[ ! -d "/var/backups/sql" ]]; then
    mkdir -p "/var/backups/sql"
fi

chmod 777 "/var/backups/sql"

for COMMAND in "mysql" "mysqldump"; do
    command_exists "${COMMAND}"
done

if [[ ! -f "/root/.my.cnf" ]]; then
    lecho "MySQL auth config not found. Creating it in /root/.my.cnf."
    MYSQL_USER="none"
    MYSQL_PASSWORD="none"
    # DirectAdmin:
    if [[ -d "/usr/local/directadmin" ]]; then
        lecho "Using MySQL config provided by Directadmin"
        source "/usr/local/directadmin/conf/mysql.conf"
        MYSQL_USER=${user}
        MYSQL_PASSWORD=${passwd}
    fi
    # cPanel / WHM:
    if [[ -d "/usr/local/cpanel" ]]; then
        lecho "Using MySQL config provided by cPanel/WHM"
        MYSQL_USER="root"
        MYSQL_PASSWORD=""
    fi
    # Parallels Plesk:
    if [[ -d "/usr/local/psa" ]]; then
        lecho "Using MySQL config provided by Plesk"
        MYSQL_USER="admin"
        MYSQL_PASSWORD="$(cat /etc/psa/.psa.shadow)"
    fi
    # OpenPanel / OpenApp:
    if [[ -d "/var/openpanel" ]]; then
        lecho "Using MySQL config provided by OpenPanel/OpenApp"
        MYSQL_USER="$(grep ^user < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')"
        MYSQL_PASSWORD="$(grep ^password < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')"
    fi
    # Debian / Ubuntu:
    if [[ -f "/etc/mysql/debian.cnf" ]]; then
        lecho "Using MySQL config provided by Debian/Ubuntu"
        MYSQL_USER="$(grep ^user < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')"
        MYSQL_PASSWORD="$(grep ^password < /etc/mysql/debian.cnf | head -1 | awk '{print $3}')"
    fi
    # ISPConfig 3:
    if [[ -f "/usr/local/ispconfig/server/lib/mysql_clientdb.conf" ]]; then
        lecho "Using MySQL config provided by ISPConfig 3"
        MYSQL_USER="$(grep user < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")"
        MYSQL_PASSWORD="$(grep password < /usr/local/ispconfig/server/lib/mysql_clientdb.conf | awk '{print $3'} | sed "s/[';]//g")"
    fi
    
    if [[ "${MYSQL_USER}" == "none" ]]; then
        lerror "Could not find MySQL username. Please add it to /root/.my.cnf to make MySQL backups work."
    fi
    if [[ "${MYSQL_PASSWORD}" == "none" ]]; then
        lerror "Could not find MySQL password. Please add it to /root/.my.cnf to make MySQL backups work." 
    fi
    
    echo "[mysqldump]" > /root/.my.cnf
    echo "user=${MYSQL_USER}" >>  /root/.my.cnf
    echo "password=${MYSQL_PASSWORD}" >>  /root/.my.cnf
    echo "[mysql]" > /root/.my.cnf
    echo "user=${MYSQL_USER}" >>  /root/.my.cnf
    echo "password=${MYSQL_PASSWORD}" >>  /root/.my.cnf
    echo "[client]" > /root/.my.cnf
    echo "user=${MYSQL_USER}" >>  /root/.my.cnf
    echo "password=${MYSQL_PASSWORD}" >>  /root/.my.cnf
    chmod 600 "/root/.my.cnf"
fi

DATABASES="$(mysql -e 'SHOW DATABASES;' | grep -v -e 'Database' -e 'information_schema')"

if [[ -z "${DATABASES}" ]]; then
    lerror "No databases found. Not backing up MySQL"
    exit 1
fi

for DB in ${DATABASES}; do
    lecho "Dumping database ${DB} to /var/backups/sql/${DB}.sql.gz"
    ionice -c2 nice -n19 mysqldump --opt --lock-all-tables --quick --hex-blob --force "${DB}" | ionice -c2 nice -n19 gzip > "/var/backups/sql/${DB}.sql.gz"
    if [[ $? -ne 0 ]]; then
        lerror "Database dump ${DB} failed."
    else
        lecho "Finished dumping database ${DB}"; echo
    fi
done


