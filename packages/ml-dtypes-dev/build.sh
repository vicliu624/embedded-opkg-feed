#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
[[ -f "$4/tdvp-sdk-manifest.json" && -d ${TDVP_FEED_STAGING_ROOT:-} ]] || exit 65
work=$(mktemp -d /tmp/tdvp-ml-dtypes-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
[[ -f "$source_root/ml_dtypes/include/float8.h" ]] || exit 66
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/include/ml_dtypes" "$payload_dir/usr/lib/cmake/ml_dtypes"
cp -a "$source_root/ml_dtypes/include" "$payload_dir/usr/include/ml_dtypes/"
cp "$package_dir/files/ml_dtypes-config.cmake" "$payload_dir/usr/lib/cmake/ml_dtypes/"
mkdir -p "$payload_dir/usr/share/licenses/ml-dtypes-dev"
cp "$source_root/LICENSE" "$source_root/LICENSE.eigen" "$payload_dir/usr/share/licenses/ml-dtypes-dev/"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$payload_dir/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
printf '%s\n' "ml-dtypes development payload ready: $payload_dir"
