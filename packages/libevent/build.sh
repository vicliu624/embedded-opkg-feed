#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-archive-library.sh
source "$package_dir/../../support/buildroot-archive-library.sh"
# tmux does not need libevent's optional OpenSSL buffers/bev support. Keep the
# public event ABI small until a consumer specifically passes TLS review. The
# desktop firmware itself selects OpenSSL, so override only libevent's recipe
# branch rather than trying to mutate that global Kconfig choice.
tdvp_build_archive_library "$package_dir" "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_LIBEVENT libevent 'libevent*.so.7*' 'LIBEVENT_VERSION = 2.1.12' \
  --make-variable 'LIBEVENT_CONF_OPTS=--disable-libevent-regress --disable-samples --disable-openssl' \
  --make-variable 'LIBEVENT_DEPENDENCIES='
