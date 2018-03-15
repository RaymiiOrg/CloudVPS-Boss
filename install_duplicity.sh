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
DUPLICITY_VERSION="0.7.17"
TITLE="CloudVPS Boss Duplicity Installer ${VERSION}"
DL_SRV="https://download.cloudvps.com/cloudvps-boss" # no ending slash (/)

if [[ ${DEBUG} == "1" ]]; then
    set -x
fi

lecho() {
    logger -t "cloudvps-boss" -- "$1"
    echo "# $1"
}

lerror() {
    logger -t "cloudvps-boss" -- "ERROR - $1"
    echo "$1" 1>&2
}

log() {
    logger -t "cloudvps-boss" -- "$1"
}

pushd () {
    command pushd "$@" > /dev/null
}

popd () {
    command popd "$@" > /dev/null
}

get_file() {
    # Download a file with curl or wget
    # get_file SAVE_TO URL
    if [[ -n "$1" && -n "$2" ]]; then
        command -v curl > /dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            command -v wget > /dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                lerror "I require curl or wget but none seem to be installed."
                lerror "Please install curl or wget"
                exit 1
            else
                wget --quiet --output-document "$1" "$2"
            fi
        else
            curl --silent --output "$1" "$2"
        fi
    else
        lerror "Not all required parameters received. Usage: get_file SAVE_TO URL"
        exit 1
    fi
}

if [[ "${EUID}" -ne 0 ]]; then
   lerror "This script must be run as root"
   exit 1
fi

log "${TITLE} started on $(date)."

if [[ -f "/etc/cloudvps-boss/duplicity_${DUPLICITY_VERSION}_installed" ]]; then
    lecho "Duplicity ${DUPLICITY_VERSION} already compiled and installed."
    exit 0
fi

cd /tmp/

distro_version() {
    if [[ -f "/etc/debian_version" ]]; then
        NAME="Debian"
        VERSION="$(awk -F. '{print $1}' /etc/debian_version)"
    fi
    if [[ -f "/etc/lsb-release" ]]; then
        NAME="$(awk -F= '/DISTRIB_ID/ {print $2}' /etc/lsb-release)"
        VERSION="$(awk -F= '/DISTRIB_RELEASE/ {print $2}' /etc/lsb-release)"
    fi
    if [[ -f "/etc/redhat-release" ]]; then
        NAME="$(awk '{ print $1 }' /etc/redhat-release)"
        VERSION="$(grep -Eo "[0-9]\.[0-9]" /etc/redhat-release | cut -d . -f 1)"
    fi
    if [[ -f "/etc/arch-release" ]]; then
        NAME="Arch"
        VERSION="Rolling"
    fi
    if [[ "$1" == "name" ]]; then
        echo "${NAME}"
    fi
    if [[ "$1" == "version" ]]; then
        echo "${VERSION}"
    fi
}

install_duplicity_debian_7() {

    APT_UPDATE="$(apt-get -qq -y --force-yes update > /dev/null 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'apt-get update' failed."
        exit 1
    fi

    APT_INSTALL="$(apt-get -qq -y --force-yes install util-linux wget dialog libc6 python build-essential libxslt1-dev libxml2-dev librsync-dev git-core python-dev python-setuptools librsync1 python-lockfile python-pip 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'apt-get install util-linux wget dialog libc6 python build-essential libxslt1-dev libxml2-dev librsync-dev git-core python-dev python-setuptools librsync1 python-lockfile python-pip' failed."
        exit 1
    fi

    mkdir -p '/usr/local/cloudvps-boss/source/duplicity'
    if [[ "$?" -ne 0 ]]; then
        lerror "'mkdir -p /usr/local/cloudvps-boss/source/duplicity' failed."
        exit 1
    fi

    touch "/usr/local/cloudvps-boss/requirements.txt"
    chmod 600 "/usr/local/cloudvps-boss/requirements.txt"
    cat << EOF > /usr/local/cloudvps-boss/requirements.txt
Babel==2.2.0
M2Crypto==0.21.1
PyYAML==3.10
argparse==1.2.1
boto==2.25.0
debtcollector==1.2.0
distribute==0.6.10
funcsigs==0.4
futures==3.0.4
iniparse==0.3.1
iso8601==0.1.11
lockfile==0.8
lxml==3.3.5
monotonic==0.6
msgpack-python==0.4.7
netaddr==0.7.18
netifaces==0.10.4
oslo.config==2.7.0
oslo.i18n==2.7.0
oslo.serialization==2.2.0
oslo.utils==2.7.0
paramiko==1.10.1
pbr==3.0.1
prettytable==0.7.2
pycrypto==2.6
pycurl==7.19.0
pyserial==2.5
python-apt==0.8.8.2
python-keystoneclient==2.3.1
python-swiftclient==3.0.0
pytz==2015.7
requests==2.9.1
six==1.10.0
stevedore==1.10.0
urlgrabber==3.9.1
wrapt==1.10.6
wsgiref==0.1.2
yolk==0.4.3
fasteners==0.14.1
keystoneauth1==2.9.0
EOF

    PIP_REQ="$(pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing dependencies with pip: 'pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt' failed."
        exit 1
    fi

    if [[ ! -d "/usr/local/cloudvps-boss/duplicity" ]]; then
        mkdir -p "/usr/local/cloudvps-boss/duplicity"
        if [[ $? -ne 0 ]]; then
            lerror "'mkdir -p /usr/local/cloudvps-boss/duplicity' failed."
            exit 1
        fi
    fi

    get_file "/usr/local/cloudvps-boss/duplicity.tar.gz" "${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "'Downloading ${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz to /usr/local/cloudvps-boss/duplicity.tar.gz failed."
        exit 1
    fi

    tar --extract --file="/usr/local/cloudvps-boss/duplicity.tar.gz" --directory="/usr/local/cloudvps-boss/duplicity/" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "'tar --extract --file=\"/usr/local/cloudvps-boss/duplicity.tar.gz\" --directory=\"/usr/local/cloudvps-boss/duplicity/\"' failed."
        exit 1
    fi

    DUPLICITY_SOURCE_FOLDER=$(find /usr/local/cloudvps-boss/duplicity/ -maxdepth 1 -iname 'duplicity-*' -type d | sort -n | tail -n 1)
    if [[ "$?" -ne 0 ]]; then
        lerror "Source folder in /usr/local/cloudvps-boss/duplicity/ not found."
        exit 1
    fi

    pushd "${DUPLICITY_SOURCE_FOLDER}"

    SETUP_INSTALL="$(python2 setup.py install 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing Duplicity: 'python2 setup.py install' failed."
        exit 1
    fi
    popd

}

install_duplicity_debian_8() {
    ## keystoneclient and swiftclient are in the repo's, no more pip.

    #swiftclient is not in precise :(
    if [[ "${DISTRO_VERSION}" == "12.04" ]]; then
        APT_UPDATE="$(apt-get -qq -y --force-yes update > /dev/null 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "'apt-get update' failed."
            exit 1
        fi

        APT_INSTALL_SOFTPROP="$(apt-get -qq -y --force-yes install software-properties-common python-software-properties > /dev/null 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "'apt-get install software-properties-common python-software-properties' failed."
            exit 1
        fi

        APT_ADD_REPO_STACK="$(add-apt-repository --yes cloud-archive:icehouse > /dev/null 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "'add-apt-repository cloud-archive:icehouse' failed."
            exit 1
        fi

        mkdir -p '/usr/local/cloudvps-boss/source/duplicity'
        if [[ "$?" -ne 0 ]]; then
            lerror "'mkdir -p /usr/local/cloudvps-boss/source/duplicity' failed."
            exit 1
        fi

        touch "/usr/local/cloudvps-boss/requirements.txt"
        chmod 600 "/usr/local/cloudvps-boss/requirements.txt"
        cat << EOF > /usr/local/cloudvps-boss/requirements.txt
fasteners==0.14.1
EOF

        PIP_REQ="$(pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "Error installing dependencies with pip: 'pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt' failed."
            exit 1
        fi

    fi

    #fasteners is not in 14.04
    if [[ "${DISTRO_VERSION}" == "14.04" ]]; then
        mkdir -p '/usr/local/cloudvps-boss/source/duplicity'
        if [[ "$?" -ne 0 ]]; then
            lerror "'mkdir -p /usr/local/cloudvps-boss/source/duplicity' failed."
            exit 1
        fi

        touch "/usr/local/cloudvps-boss/requirements.txt"
        chmod 600 "/usr/local/cloudvps-boss/requirements.txt"
        cat << EOF > /usr/local/cloudvps-boss/requirements.txt
fasteners==0.14.1
EOF

        PIP_REQ="$(pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "Error installing dependencies with pip: 'pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt' failed."
            exit 1
        fi
    fi

    if [[ "${DISTRO_VERSION}" == "16.04" || "${DISTRO_VERSION}" == "15.04" || "${DISTRO_VERSION}" == "15.10" || "${DISTRO_VERSION}" == "16.10" || "${DISTRO_VERSION}" == "17.04" || "${DISTRO_VERSION}" == "17.10" || "${DISTRO_VERSION}" == "9" || "${DISTRO_VERSION}" == "18.04" ]]; then
        APT_INSTALL="$(apt-get -qq -y --force-yes install python-fasteners 2>&1)"
        if [[ "$?" -ne 0 ]]; then
            lerror "'apt-get install python-fasteners' failed."
            exit 1
        fi
    fi

    APT_UPDATE="$(apt-get -qq -y --force-yes update > /dev/null 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'apt-get update' failed."
        exit 1
    fi

    APT_INSTALL="$(apt-get -qq -y --force-yes install util-linux wget dialog libc6 python build-essential libxslt1-dev libxml2-dev librsync-dev git-core python-dev python-setuptools librsync1 python-lockfile python-pip python-keystoneclient python-swiftclient 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'apt-get install util-linux wget dialog libc6 python build-essential libxslt1-dev libxml2-dev librsync-dev git-core python-dev python-setuptools librsync1 python-lockfile python-pip python-keystoneclient python-swiftclient' failed."
        exit 1
    fi

    mkdir -p '/usr/local/cloudvps-boss/source/duplicity'
    if [[ "$?" -ne 0 ]]; then
        lerror "'mkdir -p /usr/local/cloudvps-boss/source/duplicity' failed."
        exit 1
    fi

    if [[ ! -d "/usr/local/cloudvps-boss/duplicity" ]]; then
        mkdir -p "/usr/local/cloudvps-boss/duplicity"
        if [[ $? -ne 0 ]]; then
            lerror "'mkdir -p /usr/local/cloudvps-boss/duplicity' failed."
            exit 1
        fi
    fi

    get_file "/usr/local/cloudvps-boss/duplicity.tar.gz" "${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "'Downloading ${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz to /usr/local/cloudvps-boss/duplicity.tar.gz failed."
        exit 1
    fi

    tar --extract --file="/usr/local/cloudvps-boss/duplicity.tar.gz" --directory="/usr/local/cloudvps-boss/duplicity/" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "'tar --extract --file=\"/usr/local/cloudvps-boss/duplicity.tar.gz\" --directory=\"/usr/local/cloudvps-boss/duplicity/\"' failed."
        exit 1
    fi

    DUPLICITY_SOURCE_FOLDER=$(find /usr/local/cloudvps-boss/duplicity/ -maxdepth 1 -iname 'duplicity-*' -type d | sort -n | tail -n 1)
    if [[ "$?" -ne 0 ]]; then
        lerror "Source folder in /usr/local/cloudvps-boss/duplicity/ not found."
        exit 1
    fi

    pushd "${DUPLICITY_SOURCE_FOLDER}"

    SETUP_INSTALL="$(python2 setup.py install 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing Duplicity: 'python2 setup.py install' failed."
        exit 1
    fi
    popd

}

install_duplicity_centos_6() {

    YUM_CLEAN="$(yum -q -y clean all 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'yum clean all' failed."
        exit 1
    fi

    YUM_UPDATE="$(yum -q -y update 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'yum update' failed."
        exit 1
    fi

    YUM_DEVEL_OUTPUT=$(yum -q -y --disablerepo="*" --disableexcludes=main --enablerepo="base" --enablerepo="updates" groupinstall "Development Tools" 2>&1)
    if [[ "$?" -ne 0 ]]; then
        lerror "'yum --disablerepo=\"*\" --disableexcludes=main --enablerepo=\"base\" --enablerepo=\"updates\" groupinstall \"Development Tools\"' failed."
        exit 1
    fi

    YUM_INSTALL_BASE_OUTPUT="$(yum -q -y --disablerepo="*" --disableexcludes=main --enablerepo="base" --enablerepo="updates" install rpm-build gettext screen libxslt-python libxslt-devel python-devel python-setuptools python python-lxml wget git dialog 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'yum -q -y --disablerepo=\"*\" --disableexcludes=main --enablerepo=\"base\" --enablerepo=\"updates\" install rpm-build gettext screen libxslt-python libxslt-devel python-devel python-setuptools python python-lxml wget git dialog' failed."
        exit 1
    fi

    YUM_INSTALL_EPEL2_OUTPUT="$(yum -q -y --disablerepo="*" --disableexcludes=main --enablerepo="epel" install librsync-devel librsync python-lockfile python-pip 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "'yum -q -y --disablerepo=\"*\" --disableexcludes=main --enablerepo=\"epel\" install librsync-devel librsync python-lockfile python-pip' failed."
        exit 1
    fi

    mkdir -p '/usr/local/cloudvps-boss/duplicity'
    if [[ "$?" -ne 0 ]]; then
        lerror "Error creating Duplicity source folder."
        exit 1
    fi

    touch "/usr/local/cloudvps-boss/requirements.txt"
    chmod 600 "/usr/local/cloudvps-boss/requirements.txt"
    cat << EOF > /usr/local/cloudvps-boss/requirements.txt
argparse==1.4.0
babel==2.2.0
debtcollector==1.2.0
distribute==0.6.10
funcsigs==0.4
futures==3.0.4
importlib==1.0.1
iniparse==0.3.1
iso8601==0.1.11
lockfile==0.8
lxml==3.3.5
monotonic==0.6
msgpack-python==0.4.7
netaddr==0.7.18
netifaces==0.10.4
ordereddict==1.2
oslo.config==2.7.0
oslo.i18n==2.7.0
oslo.serialization==2.2.0
oslo.utils==2.7.0
pbr==1.8.1
prettytable==0.7.2
pycurl==7.19.0
pygpgme==0.1
python-keystoneclient==1.7.0
python-swiftclient==2.5.0
pytz==2015.7
requests==2.9.1
six==1.10.0
stevedore==1.10.0
urlgrabber==3.9.1
wrapt==1.10.6
fasteners==0.14.1
EOF


    PIP_REQ="$(pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing dependencies with pip: 'pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt' failed."
        exit 1
    fi

    if [[ ! -d "/usr/local/cloudvps-boss/duplicity" ]]; then
        mkdir -p "/usr/local/cloudvps-boss/duplicity"
        if [[ $? -ne 0 ]]; then
            lerror "Cannot create /usr/local/cloudvps-boss/duplicity"
            exit 1
        fi
    fi

    get_file "/usr/local/cloudvps-boss/duplicity.tar.gz" "${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "downloading ${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz to /usr/local/cloudvps-boss/duplicity.tar.gz failed"
        exit 1
    fi

    tar --extract --file="/usr/local/cloudvps-boss/duplicity.tar.gz" --directory="/usr/local/cloudvps-boss/duplicity/" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "Error extracting Duplicity source"
        exit 1
    fi

    DUPLICITY_SOURCE_FOLDER="$(find /usr/local/cloudvps-boss/duplicity/ -maxdepth 1 -iname 'duplicity-*' -type d | sort -n | tail -n 1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error locating Duplicity source folder."
        exit 1
    fi

    pushd "${DUPLICITY_SOURCE_FOLDER}"

    SETUP_INSTALL="$(python2 setup.py install 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing Duplicity."
        exit 1
    fi

    popd

    if [[ ! -f "/etc/profile.d/duplicity" ]]; then
        touch "/etc/profile.d/duplicity"
        echo "PATH=/usr/local/bin:$PATH" > "/etc/profile.d/duplicity"
    fi
}

install_duplicity_centos_7() {

    YUM_CLEAN="$(yum -q -y clean all 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error cleaning yum."
        exit 1
    fi

    YUM_UPDATE="$(yum -q -y update 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error updating packages."
        exit 1
    fi

    YUM_DEVEL_OUTPUT=$(yum -q -y --disablerepo="*" --disableexcludes=main --enablerepo="base" --enablerepo="updates" groupinstall "Development Tools" 2>&1)
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing development tools. Make sure base repository is enabled."
        exit 1
    fi

    YUM_INSTALL_BASE_OUTPUT="$(yum -q -y --disablerepo="*" --disableexcludes=main --enablerepo="base" --enablerepo="updates" install screen rpm-build gettext libxslt-python libxslt-devel python-lxml wget git dialog python-devel 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing required packages from base."
        exit 1
    fi

    YUM_INSTALL_EPEL_OUTPUT="$(yum -q -y --disablerepo="*"  --disableexcludes=main --enablerepo="epel" install librsync-devel librsync python-lockfile python-pip 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing required packages from epel."
        exit 1
    fi

    if [[ ! -d "/usr/local/cloudvps-boss/duplicity" ]]; then
        mkdir -p "/usr/local/cloudvps-boss/duplicity"
        if [[ $? -ne 0 ]]; then
            lerror "Cannot create /usr/local/cloudvps-boss/duplicity"
            exit 1
        fi
    fi

    touch "/usr/local/cloudvps-boss/requirements.txt"
    chmod 600 "/usr/local/cloudvps-boss/requirements.txt"
    cat << EOF > /usr/local/cloudvps-boss/requirements.txt
Babel==2.3.4
backports.ssl-match-hostname==3.4.0.2
configobj==4.7.2
debtcollector==1.5.0
decorator==3.4.0
funcsigs==1.0.2
futures==3.0.5
iniparse==0.4
IPy==0.75
iso8601==0.1.11
keystoneauth1==2.8.0
lockfile==0.9.1
lxml==3.2.1
monotonic==1.1
msgpack-python==0.4.7
netaddr==0.7.18
netifaces==0.10.4
oslo.config==3.12.0
oslo.i18n==3.7.0
oslo.serialization==2.10.0
oslo.utils==3.14.0
pbr==1.10.0
prettytable==0.7.2
pycurl==7.19.0
pygpgme==0.3
pyliblzma==0.5.3
pyparsing==1.5.6
python-keystoneclient==3.1.0
python-swiftclient==3.0.0
pytz==2016.4
pyudev==0.15
pyxattr==0.5.1
requests==2.10.0
rfc3986==0.3.1
six==1.10.0
stevedore==1.15.0
urlgrabber==3.10
wrapt==1.10.8
fasteners==0.14.1
EOF

    PIP_REQ="$(pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing dependencies with pip: 'pip install --upgrade --requirement /usr/local/cloudvps-boss/requirements.txt' failed."
        exit 1
    fi

    get_file "/usr/local/cloudvps-boss/duplicity.tar.gz" "${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "downloading ${DL_SRV}/duplicity/duplicity-${DUPLICITY_VERSION}.tar.gz to /usr/local/cloudvps-boss/duplicity.tar.gz failed."
        exit 1
    fi

    tar --extract --file="/usr/local/cloudvps-boss/duplicity.tar.gz" --directory="/usr/local/cloudvps-boss/duplicity/" 2>&1
    if [[ "$?" -ne 0 ]]; then
        lerror "Error extracting Duplicity source"
        exit 1
    fi

    DUPLICITY_SOURCE_FOLDER="$(find /usr/local/cloudvps-boss/duplicity/ -maxdepth 1 -iname 'duplicity-*' -type d | sort -n | tail -n 1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error locating Duplicity source folder."
        exit 1
    fi

    pushd "${DUPLICITY_SOURCE_FOLDER}"

    SETUP_INSTALL="$(python2 setup.py install 2>&1)"
    if [[ "$?" -ne 0 ]]; then
        lerror "Error installing Duplicity."
        exit 1
    fi

    popd

    if [[ ! -f "/etc/profile.d/duplicity" ]]; then
        touch "/etc/profile.d/duplicity"
        echo "PATH=/usr/local/bin:$PATH" > "/etc/profile.d/duplicity"
    fi
}

install_epel_7() {
    EPEL_INSTALL="$(rpm -Uvh ${DL_SRV}/utils/epel-release-7.noarch.rpm 2>&1 > /dev/null)"
}

install_epel_6() {
    EPEL_INSTALL="$(rpm -Uvh ${DL_SRV}/utils/epel-release-6.noarch.rpm 2>&1 > /dev/null)"
}

if [[ ! -f "$(which python2)" ]]; then
    if [[ ! -L "$(which python2)" ]]; then
        if [[ $(python -V 2>&1 | cut -d " " -f 2 | cut -d . -f 1) == "2" ]]; then
            ln -s "$(which python)" "$(which python)2"
        fi
    fi
fi

DISTRO_NAME=$(distro_version name)
DISTRO_VERSION=$(distro_version version)

lecho "Compiling Duplicity ${DUPLICITY_VERSION}."

case "${DISTRO_NAME}" in

    "Debian")
        case "${DISTRO_VERSION}" in
            9)
                lecho "Debian 9"
                install_duplicity_debian_8
                ;;
            8)
                lecho "Debian 8"
                install_duplicity_debian_8
                ;;
            7)
                lecho "Debian 7"
                install_duplicity_debian_7
                ;;
            *)
                lerror "Distro unknown or not supported"
                exit 1
                ;;
        esac
    ;;
    "Ubuntu")
        # ubuntu has keystoneclient and swiftclient in the repo's.
        lecho "Ubuntu ${DISTRO_VERSION}"
        install_duplicity_debian_8
    ;;
    "CentOS")
        case "${DISTRO_VERSION}" in
            7)
                lecho "CentOS 7"
                install_epel_7
                install_duplicity_centos_7
                exit
                ;;
            6)
                lecho "CentOS 6"
                install_epel_6
                install_duplicity_centos_6
                ;;
            *)
                lerror "Distro unknown or not supported"
                exit 1
                ;;
        esac
    ;;

    *)
    lerror "Distro unknown or not supported"
    exit 1
    ;;
esac

touch "/etc/cloudvps-boss/duplicity_${DUPLICITY_VERSION}_installed"

lecho "${TITLE} ended on $(date)."

