#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libngtcp2*.so*' -DENABLE_LIB_ONLY=ON -DENABLE_STATIC_LIB=OFF -DENABLE_SHARED_LIB=ON -DBUILD_TESTING=OFF -DENABLE_GNUTLS=ON -DENABLE_OPENSSL=OFF
compgen -G "$package_dir/root/usr/lib/libngtcp2_crypto_gnutls.so*" >/dev/null || exit 66
