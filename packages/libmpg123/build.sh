#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
tdvp_build_direct_archive_library "$package_dir" "$4" '' 'mpg123-1.33.7' 'libmpg123.so*' -- \
 --disable-components --enable-libmpg123 --disable-programs --disable-libout123 \
 --disable-libout123-modules --disable-libsyn123 --disable-modules --with-cpu=generic
