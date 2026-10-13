#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
[[ -x "${TDVP_FEED_STAGING_ROOT:-}/usr/bin/krb5-config" ]] || {
  echo 'TI-RPC requires the declared Kerberos development export' >&2
  exit 65
}
KRB5_CONFIG="$TDVP_FEED_STAGING_ROOT/usr/bin/krb5-config" \
  tdvp_build_direct_archive_library "$package_dir" "$4" '' 'libtirpc-1.3.7' 'libtirpc.so.[0-9]*' -- --disable-static --enable-gssapi
