#!/usr/bin/env bash
# Build selected net-tools utilities as private K230 command frontends only.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# The Buildroot recipe installs legacy utilities into paths commonly owned by
# BusyBox. Only the reviewed ELF files are retained beneath private libexec
# paths and each public launcher is tdvp-prefixed. CI compiles/audits them only:
# it never observes an interface, opens a connection, changes a route/address,
# or invokes a selected utility.
TDVP_COMMAND_FRONTEND_NAMES='arp=tdvp-arp ifconfig=tdvp-ifconfig ipmaddr=tdvp-ipmaddr iptunnel=tdvp-iptunnel mii-tool=tdvp-mii-tool nameif=tdvp-nameif netstat=tdvp-netstat plipconfig=tdvp-plipconfig rarp=tdvp-rarp route=tdvp-route slattach=tdvp-slattach' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_NET_TOOLS net-tools 'NET_TOOLS_VERSION = 2.10' \
    'arp ifconfig ipmaddr iptunnel mii-tool nameif netstat plipconfig rarp route slattach'
