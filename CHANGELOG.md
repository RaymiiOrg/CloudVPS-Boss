# Changelog

## 1.7

- Add check during install/update for already compiled dependencies.
- Add install of base-devel to Arch installer.
- Add more information to failure email script
- Change
- Change installer download paths to more clean structure.
- Fix progress reporting error when df does not support --total.
- Fix AUTH_TOKEN not found during install sometimes.
- Remove overwriting of cronjob during upgrade.
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