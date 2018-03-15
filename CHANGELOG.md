# Changelog

## 1.9.17

- Update Duplicity to 0.7.17

## 1.9.16

- Add support for Debian 9

## 1.9.16

- Update Duplicity to 0.7.16

## 1.9.13

- Update Duplicity to 0.7.15
- Add manual full backup command

## 1.9.12

- Update Duplicity to 0.7.14
- Remove pygobj dependency
- Don't chmod backup folder
- Remove duplicate log from error email
- Add new object store IP range to firewall

## 1.9.11

- Update Duplicity to 0.7.13
- Remove progress script

## 1.9.10

- Update Duplicity to 0.7.10
- Do not run fail scripts after a failed cleanup.

## 1.9.9

- Update Duplicity to 0.7.09
- Fix typo's

## 1.9.8

- Update Duplicity to 0.7.08
- Remove Arch and Fedora from the installer
- Use pip requirements for install on CentOS 7 & Debian 7
- Fix issue in cleanup script


## 1.9.7

- Update Duplicity to 0.7.07.1
- Add support for Ubuntu 16.04
- Remove CentOS 5 and Debian 6 from the installer
- Fix issue in cleanup script

## 1.9.6

- Use pip requirements for install on Debian/CentOS 6
- Remove async upload
- Add apt-get update before first package install

## 1.9.5

- Add cleanup command, wrapper around duplicity cleanup.
- Install specific versions of python libraries on Debian 6. Newer won't work with python 2.6.
- Update uninstaller to remove more python libraries.

## 1.9.4

- Fix race condition

## 1.9.3

- Install specific versions of swiftclient, keystoneclient and oslo on CentOS 6. Newer won't work with python 2.6.

## 1.9.2

- Fix install issue with mixed pip/repo packages.

## 1.9.1

- Remove requests workaround for ubuntu 14.04.
- Increase retry time.
- Update Duplicity to 0.7.05

## 1.9.0

- Add package installation on install (curl was unavailable sometimes).
- Add suggestion in error messages on failed install to let user retry the command.
- Retry MySQL credential building when authentication fails, before emailing user.
- Improve lockfile / running backup check.
- Fix large (+250 GB if 25 MB volumes or 2.5 TB if 250 MB volumes) backup sets. Only full backups were made because of https://launchpad.net/+branch/~raymii/duplicity/fix-swiftbackend-max-10000-files-in-list.
- Update some duplicity command options because of deprecation.
- Upgrade Duplicity version to 0.7.04.

## 1.8

- Add send email if MySQL backup fails.
- Change default volsize to 250 MB.
- Upgrade Duplicity version to.0.7.03.
- Upgrade Python to 2.7.10 (on new installs)

## 1.7

- Add check during install/update for already compiled dependencies.
- Add install of base-devel to Arch installer.
- Add more information to failure email script.
- Add lock file checking and handling.
- Add default MySQL data dir to exclude list.
- Change installer download paths to more clean structure.
- Upgrade Duplicity version to 0.7.01.
- Upgrade Duplicity version to 0.7.02.
- Remove overwriting of cronjob during upgrade.
- Fix progress reporting error when df does not support --total.
- Fix rare AUTH_TOKEN not found during install.
- Fix curl dependency check in installer
- Fix curl not found error in credential script



## 1.6

- Add view progress command for long running backups.
- Add section for large backups to README.
- Add https download link to README.
- Add bandwidth limit instructions to README.
- Add wget/curl wrapper for remote file downloading.
- Add more clear encryption instructions.
- Add workaround when AUTH_TOKEN during credential setup fails.
- Change default exclude list.
- Change update download link to https.
- Change internal json functions to be more clear.
- Change default retention to 3 months instead of 6.
- Fix installer bug when multiple duplicity source folders exist.
- Fix installer bug when install fails on immutable scripts.
- Remove some non used code.

## 1.5

- Add custom backend support.
- Add custom additional options support.
- Add use of duplicity --name parameter.
- Add documentation on manual cleanup.
- Change auto update to run once a week.
- Fix uninstaller when pip was not named pip.
- Fix some quoting issues.

## 1.4

- Add encryption setup support.
- Add yum clean before update and install
- Add /home/virtfs to exclude list (cpanel)
- Add upload of version number to status folder during updates
- Change more clear documentation on projects and user accounts.
- Fix installation error on CentOS 5 sqlite
- Fix installation error on cpanel + Centos 6.
- Fix no compilation in /tmp (noexec errors)

## 1.3

- Initial public release
