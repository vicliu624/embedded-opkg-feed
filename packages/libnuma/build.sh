#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
sdk_root=$4
stage_root=${TDVP_FEED_STAGING_ROOT:?}
[[ -d "$stage_root" && ! -L "$stage_root" ]] || exit 64
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-numa-build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
cd "$source_root"
export CFLAGS="$CFLAGS -fPIC -O1 -ffile-prefix-map=$source_root=/usr/src/numactl"
./configure --host=riscv64-unknown-linux-gnu --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static
make -j"${TDVP_JOBS:-2}" libnuma.la
make DESTDIR="$work/install" install-libLTLIBRARIES install-includeHEADERS install-pkgconfigDATA
# Do not export libtool's toolchain-path dependency metadata to consumers.
rm -f -- "$work/install/usr/lib/libnuma.la"
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$stage_root/usr"
cp -a "$work/install/usr/lib/"libnuma.so.[0-9]* "$payload_dir/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
cp -a "$work/install/usr/." "$stage_root/usr/"
# Consumers must see the same RPATH-free library, not the unclean libtool copy.
cp -a "$payload_dir/usr/lib/." "$stage_root/usr/lib/"
notice_args=()
while IFS= read -r file; do notice_args+=(--file "${file#"$source_root/"}"); done < <(grep -ilE 'copyright|SPDX-License-Identifier' "$source_root/"*.c "$source_root/"*.h)
python3 "$package_dir/../../support/extract-source-copyright-notices.py" "$source_root" "$source_root/TDVP-COPYRIGHT-NOTICE" "${notice_args[@]}"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" --license-file LICENSE.LGPL2.1 --license-file LICENSE.GPL2 --license-file TDVP-COPYRIGHT-NOTICE
mkdir -p "$stage_root/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$stage_root/usr/share/licenses/"
printf 'libnuma RPATH-free runtime and development staging ready: %s\n' "$payload_dir"
