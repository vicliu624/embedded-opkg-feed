#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
[[ -f "$4/tdvp-sdk-manifest.json" && -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 65
work=$(mktemp -d /tmp/tdvp-mp11-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
[[ -f "$source_root/include/boost/mp11.hpp" ]] || exit 66
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/include" "$payload_dir/usr/lib/cmake/boost_mp11"
cp -a "$source_root/include/boost" "$payload_dir/usr/include/"
cp "$package_dir/files/boost_mp11-config.cmake" "$payload_dir/usr/lib/cmake/boost_mp11/"
mkdir -p "$payload_dir/usr/share/licenses/boost-mp11-dev"
# Exact license from https://raw.githubusercontent.com/boostorg/boost/boost-1.82.0/LICENSE_1_0.txt
[[ "$(sha256sum "$package_dir/files/LICENSE_1_0.txt" | cut -d' ' -f1)" == \
   c9bff75738922193e67fa726fa225535870d2aa1059f91452c411736284ad566 ]] || exit 67
cp "$package_dir/files/LICENSE_1_0.txt" "$payload_dir/usr/share/licenses/boost-mp11-dev/"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$payload_dir/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
printf '%s\n' "Boost.MP11 development payload ready: $payload_dir"
