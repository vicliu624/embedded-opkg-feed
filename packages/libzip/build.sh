#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
# Bound decoder memory to 64 MiB; this upstream option requires bytes, not ON.
tdvp_build_cmake_source_library "$package_dir" "$4" 'libzip.so*' -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF -DENABLE_COMMONCRYPTO=OFF -DENABLE_WINDOWS_CRYPTO=OFF -DENABLE_GNUTLS=OFF -DENABLE_OPENSSL=ON -DLIMIT_LZMA_WINDOW=67108864
