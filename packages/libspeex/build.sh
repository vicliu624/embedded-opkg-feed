#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
tdvp_build_direct_archive_library "$package_dir" "$4" '' 'speex-1.2.1' 'libspeex.so*' -- \
 --disable-binaries --disable-sse --disable-arm4-asm --disable-arm5e-asm \
 --disable-blackfin-asm --disable-ti-c55x --disable-fixed-point
