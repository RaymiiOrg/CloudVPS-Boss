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

set -o pipefail

VERSION="1.9.17"
TITLE="CloudVPS Boss Credentials Config ${VERSION}"

if [[ ${DEBUG} == "1" ]]; then
    set -x
fi

usage() {
    echo "# ./${0} [username] [password] [tenant_id]"
    echo "# Interactive: ./$0"
    echo "# Noninteractive: ./$0 'user@example.org' 'P@ssw0rd' 'aeae1234...'"
    exit 1
}

lecho() {
    logger -t "cloudvps-boss" -- "$1"
    echo "# $1"
}

lerror() {
    logger -t "cloudvps-boss" -- "ERROR - $1"
    echo "$1" 1>&2
}

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

if [[ ! -d "/etc/cloudvps-boss" ]]; then
    mkdir -p "/etc/cloudvps-boss"
    if [[ $? -ne 0 ]]; then
        lerror "Cannot create /etc/cloudvps-boss"
        exit 1
    fi
fi

if [[ -f "/etc/boss-backup/auth.conf" ]]; then
    lecho "Boss-backup beta auth config found. Copying it."
    cp "/etc/boss-backup/auth.conf" "/etc/cloudvps-boss/auth.conf"
fi

if [[ -f "/etc/swiftbackup/auth.conf" ]]; then
    lecho "Swiftbackup beta auth config found. Copying it."
    cp "/etc/swiftbackup/auth.conf" "/etc/cloudvps-boss/auth.conf"
fi

if [[ -f "/etc/cloudvps-boss/auth.conf" ]]; then
    lecho "/etc/cloudvps-boss/auth.conf already exists. Not overwriting it"
    exit
fi

if [[ "${1}" == "help" ]]; then
    usage
elif [[ -z ${2} || -z ${1} || -z ${3} ]]; then
    echo; echo; echo; echo; echo;
    read -e -p "Openstack Username (user@example.org): " USERNAME
    read -e -s -p "Openstack Password (not shown):" PASSWORD
    echo
    read -e -p "Openstack Tenant ID: " TENANT_ID
else
    USERNAME="${1}"
    PASSWORD="${2}"
    TENANT_ID="${3}"
fi

if [[ -z "${USERNAME}" || -z "${PASSWORD}" || -z "${TENANT_ID}" ]]; then
    echo
    lerror "Need username and password and tenant id."
    exit 1
fi

OS_BASE_AUTH_URL="https://identity.stack.cloudvps.com/v2.0"
OS_AUTH_URL="${OS_BASE_AUTH_URL}/tokens"
OS_TENANTS_URL="${OS_BASE_AUTH_URL}/tenants"

command -v curl > /dev/null 2>&1
if [[ $? -ne 0 ]]; then
    command -v wget > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        lerror "I require curl or wget but none seem to be installed."
        lerror "Please install curl or wget"
        exit 1
    else
        AUTH_TOKEN=$(wget -q --header="Content-Type: application/json" --header "Accept: application/json" -O - --post-data='{"auth": {"tenantName": "'${TENANT_ID}'", "passwordCredentials": {"username": "'${USERNAME}'", "password": "'${PASSWORD}'"}}}' "${OS_AUTH_URL}" | grep -o '\"id\": \"[^\"]*\"' | awk -F\" '{print $4}' | sed -n 1p)
    fi
else
    AUTH_TOKEN=$(curl -s "${OS_AUTH_URL}" -X POST -H "Content-Type: application/json" -H "Accept: application/json"  -d '{"auth": {"tenantName": "'${TENANT_ID}'", "passwordCredentials": {"username": "'${USERNAME}'", "password": "'${PASSWORD}'"}}}' | grep -o '\"id\": \"[^\"]*\"' | awk -F\" '{print $4}' | sed -n 1p)
fi

if [[ -z "${TENANT_ID}" ]]; then
    lerror "Tenant ID could not be found. Check username, password or network connectivity."
    exit 1
fi

if [[ -z "${AUTH_TOKEN}" ]]; then
    lecho "AUTH_TOKEN empty. Trying again."
    sleep 5
    command -v curl > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        command -v wget > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            lerror "I require curl or wget but none seem to be installed."
            lerror "Please install curl or wget"
            exit 1
        else
            AUTH_TOKEN=$(wget -q --header="Content-Type: application/json" --header "Accept: application/json" -O - --post-data='{"auth": {"tenantName": "'${TENANT_ID}'", "passwordCredentials": {"username": "'${USERNAME}'", "password": "'${PASSWORD}'"}}}' "${OS_AUTH_URL}" | grep -o '\"id\": \"[^\"]*\"' | awk -F\" '{print $4}' | sed -n 1p)
        fi
    else
        AUTH_TOKEN=$(curl -s "${OS_AUTH_URL}" -X POST -H "Content-Type: application/json" -H "Accept: application/json"  -d '{"auth": {"tenantName": "'${TENANT_ID}'", "passwordCredentials": {"username": "'${USERNAME}'", "password": "'${PASSWORD}'"}}}' | grep -o '\"id\": \"[^\"]*\"' | awk -F\" '{print $4}' | sed -n 1p)
    fi
    if [[ -z "${AUTH_TOKEN}" ]]; then
        lerror "AUTH_TOKEN could not be found after two tries. Check username, password or network connectivity."
        exit 1
    fi
fi

SWIFT_USERNAME="${TENANT_ID}:${USERNAME}"
SWIFT_PASSWORD="${PASSWORD}"
SWIFT_AUTHVERSION="2"
SWIFT_AUTHURL="${OS_BASE_AUTH_URL}"

if [[ ! -f "/etc/cloudvps-boss/auth.conf" ]]; then
    touch "/etc/cloudvps-boss/auth.conf"
    chmod 600 "/etc/cloudvps-boss/auth.conf"
    cat << EOF > /etc/cloudvps-boss/auth.conf
export SWIFT_USERNAME="${SWIFT_USERNAME}"
export SWIFT_PASSWORD="${SWIFT_PASSWORD}"
export SWIFT_AUTHURL="${SWIFT_AUTHURL}"
export SWIFT_AUTHVERSION="${SWIFT_AUTHVERSION}"
export OS_AUTH_URL="${OS_BASE_AUTH_URL}"
export OS_TENANT_NAME="${TENANT_ID}"
export OS_USERNAME="${USERNAME}"
export OS_PASSWORD="${PASSWORD}"
export OS_TENANT_ID="${TENANT_ID}"
EOF
    lecho "Written auth config to /etc/cloudvps-boss/auth.conf."
else
    lecho "/etc/cloudvps-boss/auth.conf already exists. Not overwriting it"
fi

lecho "Username: ${SWIFT_USERNAME}"
lecho "Auth URL: ${SWIFT_AUTHURL}"
lecho "Checking Swift Container for Backups: https://public.objectstore.eu/v1/${TENANT_ID}/cloudvps-boss-backup/"

curl -s -o /dev/null -X PUT -T "/etc/hosts" --user "${USERNAME}:${PASSWORD}" "https://public.objectstore.eu/v1/${TENANT_ID}/cloudvps-boss-backup/"
if [[ $? == 60 ]]; then
    # CentOS 5...
    lecho "Curl error Peer certificate cannot be authenticated with known CA certificates."
    lecho "This is probably CentOS 5. CentOS 5 is deprecated. Exiting"
    exit 1
fi
