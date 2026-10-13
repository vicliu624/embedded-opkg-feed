#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libssh.so.[0-9]*' \
 -DWITH_GSSAPI=ON -DWITH_ZLIB=ON -DWITH_SFTP=ON -DWITH_SERVER=ON \
 -DWITH_PCAP=ON -DWITH_EXAMPLES=OFF -DUNIT_TESTING=OFF \
 -DCLIENT_TESTING=OFF -DSERVER_TESTING=OFF -DWITH_BENCHMARKS=OFF \
 -DWITH_GCRYPT=OFF -DWITH_MBEDTLS=OFF -DWITH_SYMBOL_VERSIONING=ON
