#!/usr/bin/env bash
# Build a bounded, plaintext iperf3 network diagnostic command from the
# locked Buildroot source.  The tool is private to its IPK and never replaces
# a BusyBox binary in the immutable firmware.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_DEVEL_BUILDROOT_OUTPUT || true)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
for required_config in BR2_TOOLCHAIN_HAS_ATOMIC=y BR2_TOOLCHAIN_HAS_THREADS=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required iperf3 toolchain feature: $required_config" >&2
    exit 65
  }
done

# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# iperf3 can use OpenSSL for its optional authentication mode. The desktop
# firmware legitimately selects OpenSSL, so do not alter that global Kconfig
# state. Override only this private package recipe: --without-openssl prevents
# the link, static-only output keeps libiperf private to this executable, and
# clearing its dependency list prevents an unreviewed host-pkgconf or OpenSSL
# build path from entering the source-locked transaction.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='IPERF3_CONF_OPTS=--without-openssl --disable-shared --enable-static
IPERF3_DEPENDENCIES=' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "$configured_output" \
    BR2_PACKAGE_IPERF3 iperf3 'IPERF3_VERSION = 3.18' 'iperf3'
