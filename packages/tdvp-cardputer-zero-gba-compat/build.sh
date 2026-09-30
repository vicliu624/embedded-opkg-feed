#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
[[ "$PACKAGE" == tdvp-cardputer-zero-gba && "$PACKAGE_DEPENDS" == tdvp-gba
   && "$PACKAGE_KIND" == application && "$PACKAGE_BASE_OVERLAY" == deny ]] || exit 65
source "$package_dir/../../support/source-archive-library.sh"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
[[ -z "$(find "$payload" -mindepth 1 -print -quit)" ]] || exit 66
echo 'historical GBA package name now depends on the supported tdvp-gba application'
