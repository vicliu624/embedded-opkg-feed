#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libopencv*.so*' \
  -DBUILD_LIST=core,imgproc,imgcodecs,calib3d,features2d,flann,video,objdetect,dnn,videoio \
  -DBUILD_TESTS=OFF -DBUILD_PERF_TESTS=OFF -DBUILD_EXAMPLES=OFF \
  -DBUILD_opencv_apps=OFF -DBUILD_opencv_python2=OFF -DBUILD_opencv_python3=OFF \
  -DBUILD_JPEG=OFF -DBUILD_PNG=OFF -DBUILD_TIFF=OFF -DBUILD_WEBP=OFF -DBUILD_ZLIB=OFF \
  -DWITH_JPEG=ON -DWITH_PNG=ON -DWITH_TIFF=ON -DWITH_WEBP=ON -DWITH_FFMPEG=ON \
  -DWITH_V4L=OFF -DWITH_LIBV4L=OFF -DWITH_GTK=OFF -DWITH_QT=OFF \
  -DWITH_OPENCL=OFF -DWITH_IPP=OFF -DWITH_ITT=OFF -DWITH_OPENEXR=OFF \
  -DWITH_OPENJPEG=OFF -DWITH_JASPER=OFF -DWITH_GSTREAMER=OFF \
  -DCPU_BASELINE=NONE -DCPU_DISPATCH= -DOPENCV_GENERATE_PKGCONFIG=ON \
  -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config
# WITH_* is only a request: OpenCV may silently fall back to bundled codecs.
# Require actual dynamic dependencies on the separately owned feed providers.
for soname in libtiff.so.6 libwebp.so.7; do
  "$4/bin/riscv64-unknown-linux-gnu-readelf" -d \
    "$package_dir/root/usr/lib/libopencv_imgcodecs.so.4.10.0" | \
    grep -Fq "Shared library: [$soname]" || {
      echo "OpenCV omitted external runtime provider: $soname" >&2
      exit 68
    }
done
