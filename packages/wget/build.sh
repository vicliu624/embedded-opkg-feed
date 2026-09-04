#!/usr/bin/env bash
# Build a small OpenSSL-based Wget command from the locked Buildroot source.
# Its optional TLS/IDN/PSL/UUID/regex/DNS feature graph is deliberately held
# to providers already admitted to this TDVP feed release.
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
for required_config in BR2_PACKAGE_OPENSSL=y BR2_PACKAGE_LIBOPENSSL=y BR2_PACKAGE_ZLIB=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required Wget SDK feature: $required_config" >&2
    exit 65
  }
done

# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# Keep one auditable TLS path: OpenSSL and zlib are separately owned feed
# providers. The desktop SDK may enable other global Kconfig features, so
# override this private Buildroot recipe's configure/dependency variables
# instead of mutating or depending on that immutable SDK configuration.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='WGET_DEPENDENCIES=host-pkgconf openssl zlib
WGET_CONF_OPTS=--without-libpsl --with-ssl openssl --disable-iri --without-libuuid --with-zlib --without-cares --disable-pcre --disable-pcre2' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "$configured_output" \
    BR2_PACKAGE_WGET wget 'WGET_VERSION = 1.25.0' 'wget'
