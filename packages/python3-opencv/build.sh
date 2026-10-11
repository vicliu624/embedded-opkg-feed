#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
stage=${TDVP_FEED_STAGING_ROOT:?}
[[ -f "$stage/usr/include/python3.13/Python.h" &&
   -f "$stage/usr/lib/python3.13/site-packages/numpy/_core/include/numpy/arrayobject.h" &&
   -f "$stage/usr/lib/pkgconfig/opencv4.pc" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-opencv-python.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source" "$work/generated"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
# Mirror the upstream bindings generator's public-header selection. Build
# wrappers only; never rebuild OpenCV runtime modules for this consumer.
python3 - "$source_root" "$work/generated" "$stage/usr/include/opencv4" <<'PY'
import pathlib, re, sys
source, output, installed = map(pathlib.Path, sys.argv[1:])
modules = ['core', 'imgproc', 'imgcodecs', 'calib3d', 'features2d', 'flann', 'video', 'objdetect', 'dnn', 'videoio']
headers, custom = [], []
for module in modules:
    root = source / 'modules' / module
    for header in sorted((root / 'include').rglob('*.hpp'),
                         key=lambda h: (len(h.relative_to(root / 'include').parts), h.as_posix())):
        if not (installed / header.relative_to(root / 'include')).is_file(): continue
        name = header.as_posix()
        if any(part in name for part in ['/cuda/', '/hal/', '/opencl/', '/utils/', '/legacy/']): continue
        if any(part in header.name for part in ['_inl.', '.inl.', '.details.', '.private.', 'private.', 'detection_based_tracker']): continue
        headers.append(header)
    misc = root / 'misc' / 'python'
    headers += sorted(misc.glob('python_*.hpp')) + sorted(misc.glob('shadow*.hpp'))
    custom += sorted(misc.glob('python_*.hpp')) + sorted(misc.glob('pyopencv*.hpp'))
(output / 'headers.txt').write_text('\n'.join(map(str, headers)) + '\n')
(output / 'pyopencv_custom_headers.h').write_text('\n'.join('#include "' + str(h) + '"' for h in custom) + '\n')
PY
python3 "$source_root/modules/python/src2/gen2.py" "$work/generated" "$work/generated/headers.txt"
source "$sdk_root/environment-setup.sh"
export PKG_CONFIG_SYSROOT_DIR="$stage"
export PKG_CONFIG_LIBDIR="$stage/usr/lib/pkgconfig"
export PKG_CONFIG_PATH=''
IFS=' ' read -r -a libraries <<<"$(/usr/bin/pkg-config --libs opencv4)"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
destination="$payload/usr/lib/python3.13/site-packages"
mkdir -p "$destination"
"$sdk_root/bin/riscv64-unknown-linux-gnu-g++" --sysroot="$sdk_root/sysroot" \
  -O1 -fPIC -shared -std=c++11 \
  -I"$work/generated" -I"$source_root/modules/python/src2" \
  -I"$source_root/modules/core/include" \
  -I"$stage/usr/include/opencv4" -I"$stage/usr/include/python3.13" \
  -I"$stage/usr/lib/python3.13/site-packages/numpy/_core/include" \
  "$source_root/modules/python/src2/"*.cpp \
  -Wl,-rpath-link,"$stage/usr/lib" "${libraries[@]}" \
  -o "$destination/cv2.cpython-313-riscv64-linux-gnu.so"
"$STRIP" --strip-unneeded "$destination/"*.so
tdvp_assert_elf_without_runtime_search_path "$READELF" "$destination/"*.so
mkdir -p "$stage/usr/lib/python3.13/site-packages"
cp -a "$destination/." "$stage/usr/lib/python3.13/site-packages/"
python3 "$package_dir/../../support/install-source-licenses.py" \
  "$source_root" "$package_dir" "$payload" --license-file LICENSE
printf '%s\n' "OpenCV Python wrapper ready: $payload"
