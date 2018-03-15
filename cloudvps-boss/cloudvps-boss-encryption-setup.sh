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
TITLE="CloudVPS Boss Encryption Setup ${VERSION}"

if [[ ! -f "/etc/cloudvps-boss/common.sh" ]]; then
    lerror "Cannot find /etc/cloudvps-boss/common.sh"
    exit 1
fi
source /etc/cloudvps-boss/common.sh

for COMMAND in "gpg"; do
    command_exists "${COMMAND}"
done

if [[ ! -d "/etc/cloudvps-boss/encryption" ]]; then
    mkdir -p "/etc/cloudvps-boss/encryption"
    chmod 600 "/etc/cloudvps-boss/encryption"
else
    if [[ -f "/etc/cloudvps-boss/encryption/setup-finished" ]]; then
        lecho "Encryption already set up."
        exit 0
    fi
fi

echo "You are going to set up encryption for your backups."
echo "You need to have a good key backup, testing and recovery"
echo "procedure. A lot of information will be shown on the "
echo "screen when the setup is done. Make sure to back that up."
echo ""
echo "Please note that when encryption is set up, support from CloudVPS is not possible."
echo ""
read -e -p "Please type 'I have a good key management procedure and want to set up encryption.': " CONFIRM_ENCRYPTION_SETUP

if [[ "${CONFIRM_ENCRYPTION_SETUP}" != 'I have a good key management procedure and want to set up encryption.' ]]; then
    echo "Input not correct."
    exit 1
fi


lecho "Placing signing key gpg config"
cat > /etc/cloudvps-boss/encryption/sign-key.gpg.conf <<SIGNKEY
%echo Generating CloudVPS Boss backup signing key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: ELG-E
Subkey-Length: 2048
Name-Real: CloudVPS Boss Backup Signing Key for ${HOSTNAME}
Name-Email: backup-signing@${HOSTNAME}
Expire-Date: 0
%commit
%echo Done
SIGNKEY
if [[ "$?" -ne 0 ]]; then
    lerror "Error placing signing key gpg config"
    exit 1
fi

lecho "Placing encryption key gpg config"
cat > /etc/cloudvps-boss/encryption/enc-key.gpg.conf <<ENCKEY
%echo Generating CloudVPS Boss backup encryption key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: ELG-E
Subkey-Length: 2048
Name-Real: CloudVPS Boss Backup Encryption Key for ${HOSTNAME}
Name-Email: backup-encryption@${HOSTNAME}
Expire-Date: 0
%commit
%echo Done
ENCKEY
if [[ "$?" -ne 0 ]]; then
    lerror "Error placing encryption key gpg config"
    exit 1
fi

echo
lecho "The key generation might take a long time. To speed"
lecho "it up, open another session on this machine and do"
lecho "some work, make the disk active, openssl speed etc."
echo

lecho "Generating signing key with gpg."
gpg --batch --gen-key /etc/cloudvps-boss/encryption/sign-key.gpg.conf > /etc/cloudvps-boss/encryption/gen-sign-key.log 2> /etc/cloudvps-boss/encryption/gen-sign-key.error.log
if [[ "$?" -ne 0 ]]; then
    lerror "Error generating signing key with gpg"
    exit 1
fi


lecho "Generating encryption key with gpg."
gpg --batch --gen-key /etc/cloudvps-boss/encryption/enc-key.gpg.conf > /etc/cloudvps-boss/encryption/gen-enc-key.log 2> /etc/cloudvps-boss/encryption/gen-enc-key.error.log
if [[ "$?" -ne 0 ]]; then
    lerror "Error generating encryption key with gpg"
    exit 1
fi

touch "/etc/cloudvps-boss/encryption.conf"
chmod 600 "/etc/cloudvps-boss/encryption.conf"

SIGN_KEY_ID="$(awk '/marked as ultimately trusted/ {print $3}' /etc/cloudvps-boss/encryption/gen-sign-key.error.log)" #| gpg --list-keys --with-colon | awk -F: '/pub/ {print $5}')"
ENC_KEY_ID="$(awk '/marked as ultimately trusted/ {print $3}' /etc/cloudvps-boss/encryption/gen-enc-key.error.log)" # | gpg --list-keys --with-colon | awk -F: '/pub/ {print $5}')"

echo "# CloudVPS Boss Encryption Config file ${VERSION}" >> /etc/cloudvps-boss/encryption.conf
echo "SIGN_KEY='${SIGN_KEY_ID}'" >> /etc/cloudvps-boss/encryption.conf
echo "ENC_KEY='${ENC_KEY_ID}'" >> /etc/cloudvps-boss/encryption.conf

echo "ENCRYPTION_OPTIONS=\"--encrypt-key=${ENC_KEY_ID} --sign-key=${SIGN_KEY_ID} \"" >> /etc/cloudvps-boss/encryption.conf

echo; echo; echo; echo; echo;
read -e -p "Please save the following information. Press ENTER to continue."

echo "===== BEGIN IMPORTANT RESTORE INFORMATION ====="
echo "Please backup the following in full."
echo "If you don't, or loose it, you will not"
echo "be able to access or restore your backups."
echo "Don't share this with anyone. This information"
echo "gives complete access to this backup."
echo ""
echo "===== SIGNING KEY ====="
echo "GPG Info:"
gpg --list-key "${SIGN_KEY_ID}"
gpg --export-secret-key -a "<backup-signing@${HOSTNAME}>"
echo ""
echo "===== ENCRYPTION KEY ====="
echo "GPG Info:"
gpg --list-key "${ENC_KEY_ID}"
gpg --export-secret-key -a "<backup-encryption@${HOSTNAME}>"
echo ""
echo "===== GPG Ownertrust ====="
gpg --export-ownertrust
echo ""
echo "===== ENCRYPTION CONFIG ====="
cat /etc/cloudvps-boss/encryption.conf
echo ""
echo "To restore these keys: place the contents"
echo "in 2 files, sign.key and encryption.key."
echo "Execute the following commands as root:"
echo "# gpg --import-key sign.key"
echo "# gpg --import-key encryption.key"
echo ""
echo "Restore the configuration printed above"
echo "to /etc/cloudvps-boss/encryption.conf."
echo ""
echo "Place the ownertrust contents in a file"
echo "named 'ownertrust.gpg' and import it:"
echo "# gpg --import-ownertrust ownertrust.gpg"
echo ""
echo "===== END IMPORTANT RESTORE INFORMATION ====="
echo ""

lecho "Cleaning up config files."
rm "/etc/cloudvps-boss/encryption/gen-sign-key.error.log" "/etc/cloudvps-boss/encryption/gen-sign-key.log" "/etc/cloudvps-boss/encryption/gen-enc-key.error.log" "/etc/cloudvps-boss/encryption/gen-enc-key.log" "/etc/cloudvps-boss/encryption/enc-key.gpg.conf" "/etc/cloudvps-boss/encryption/sign-key.gpg.conf"

lecho "Removing secret key used for encryption."
# first get fingerprint, otherwise non-interactive remove fails
ENC_KEY_FINGERPRINT="$(gpg --list-secret-keys --with-colons --fingerprint | grep "${ENC_KEY_ID}" | sed -n 's/^fpr:::::::::\([[:alnum:]]\+\):/\1/p')"

gpg --batch --yes --delete-secret-key "${ENC_KEY_FINGERPRINT}"

lecho "Encryption setup done. Please make a backup now, execute 'cloudvps-boss'."

touch /etc/cloudvps-boss/encryption/setup-finished
if [[ "$?" -ne 0 ]]; then
    lerror "Error completing setup, could not touch finish file."
    exit 1
fi
