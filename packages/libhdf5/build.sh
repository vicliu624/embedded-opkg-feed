#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
sdk_root=$4
tdvp_build_cmake_source_library "$package_dir" "$sdk_root" 'libhdf5*.so.[0-9]*' \
  "-DCMAKE_CROSSCOMPILING_EMULATOR=qemu-riscv64;-L;$sdk_root/sysroot;-E;LD_LIBRARY_PATH=$TDVP_FEED_STAGING_ROOT/usr/lib" \
  -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF \
  -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF -DHDF5_BUILD_CPP_LIB=ON \
  -DHDF5_BUILD_HL_LIB=ON -DHDF5_BUILD_FORTRAN=OFF -DHDF5_ENABLE_PARALLEL=OFF \
  -DHDF5_ENABLE_THREADSAFE=OFF -DHDF5_ALLOW_UNSUPPORTED=OFF \
  -DHDF5_ENABLE_ZLIB_SUPPORT=ON -DHDF5_ENABLE_SZIP_SUPPORT=ON \
  -DHDF5_ENABLE_SZIP_ENCODING=ON -DHDF5_USE_LIBAEC_STATIC=OFF
