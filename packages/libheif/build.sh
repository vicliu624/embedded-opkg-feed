#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
[[ -f "${TDVP_FEED_STAGING_ROOT:?}/usr/include/webp/sharpyuv/sharpyuv.h" ]] || {
  echo 'HEIF requires the verified libwebp-7 SharpYUV development projection' >&2
  exit 66
}
tdvp_build_cmake_source_library "$package_dir" "$4" 'libheif.so.[0-9]*' \
  -DWITH_LIBSHARPYUV=ON -DWITH_LIBSHARPYUV_INTERNAL=OFF \
  "-DLIBSHARPYUV_INCLUDE_DIR=$TDVP_FEED_STAGING_ROOT/usr/include/webp" \
  -DWITH_LIBDE265=ON -DWITH_LIBDE265_PLUGIN=OFF \
  -DWITH_X265=ON -DWITH_X265_PLUGIN=OFF \
  -DWITH_AOM_ENCODER=ON -DWITH_AOM_ENCODER_PLUGIN=OFF \
  -DWITH_AOM_DECODER=ON -DWITH_AOM_DECODER_PLUGIN=OFF \
  -DWITH_JPEG_ENCODER=ON -DWITH_JPEG_ENCODER_PLUGIN=OFF \
  -DWITH_JPEG_DECODER=ON -DWITH_JPEG_DECODER_PLUGIN=OFF \
  -DWITH_OpenJPEG_ENCODER=ON -DWITH_OpenJPEG_ENCODER_PLUGIN=OFF \
  -DWITH_OpenJPEG_DECODER=ON -DWITH_OpenJPEG_DECODER_PLUGIN=OFF \
  -DWITH_OPENJPH_ENCODER=ON -DWITH_OPENJPH_ENCODER_PLUGIN=OFF \
  -DWITH_UNCOMPRESSED_CODEC=ON -DWITH_EXAMPLES=OFF \
  -DWITH_GDK_PIXBUF=OFF -DBUILD_TESTING=OFF -DWITH_DOCUMENTATION=OFF \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
