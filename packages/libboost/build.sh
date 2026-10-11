#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$repo_root/scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/elf-runtime-policy.sh"
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -d "${TDVP_FEED_STAGING_ROOT:?}/usr" ]] || exit 65
for header in python3.13/Python.h python3.13/pyconfig.h unicode/utypes.h bzlib.h lzma.h zstd.h; do
 [[ -f "$TDVP_FEED_STAGING_ROOT/usr/include/$header" ]] || {
  echo "Boost development provider omitted $header" >&2; exit 66;
 }
done
work=$(mktemp -d /tmp/tdvp-boost-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/sysroot"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
# B2 runs on the build host. Inherited target variables cannot select its compiler.
(cd "$source_root" && env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
 -u AR -u AS -u LD -u NM -u STRIP -u RANLIB bash ./bootstrap.sh --with-toolset=gcc)
python3 - "$sdk_root" "$work" <<'PY'
import json
from pathlib import Path
import sys
sdk = Path(sys.argv[1]).resolve(strict=True)
work = Path(sys.argv[2]).resolve(strict=True)
configuration = 'using gcc : tdvp : ' + json.dumps(str(sdk / 'bin/riscv64-unknown-linux-gnu-g++')) + ' ;\n'
configuration += ('using python : 3.13 : /usr/bin/python3 : ' + json.dumps(str(work / 'sysroot/usr/include/python3.13')) +
                  ' : ' + json.dumps(str(work / 'sysroot/usr/lib')) + ' ;\n')
(work / 'user-config.jam').write_text(configuration)
PY
source "$sdk_root/environment-setup.sh"
(cd "$source_root" && ./b2 --ignore-site-config --user-config="$work/user-config.jam" \
 --build-dir="$work/build" --prefix="$work/install/usr" --libdir="$work/install/usr/lib" \
 -j"${TDVP_JOBS:-2}" toolset=gcc-tdvp target-os=linux architecture=riscv address-model=64 \
 abi=sysv binary-format=elf threading=multi link=shared runtime-link=shared variant=release python=3.13 \
 "cxxflags=$CXXFLAGS --sysroot=$work/sysroot -march=rv64imafdc -mabi=lp64d -O1 -ffile-prefix-map=$work=/usr/src/tdvp/libboost" \
 "linkflags=--sysroot=$work/sysroot -march=rv64imafdc -mabi=lp64d -Wl,-rpath-link,$work/sysroot/usr/lib" \
 "-sICU_PATH=$work/sysroot/usr" install)
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
libraries=("$work/install/usr/lib/"libboost_*.so.1.82.0)
[[ ${#libraries[@]} -ge 38 ]] || exit 67
for library in python313 filesystem thread regex serialization locale iostreams context fiber; do
 [[ -f "$work/install/usr/lib/libboost_$library.so.1.82.0" ]] || exit 68
done
cp -a "${libraries[@]}" "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" --license-file LICENSE_1_0.txt
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
cp -a "$payload/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
echo "Boost complete runtime and development projection ready: $payload"
