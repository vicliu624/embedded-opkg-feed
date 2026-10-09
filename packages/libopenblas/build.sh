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
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 65
fc="$sdk_root/toolchain/bin/riscv64-unknown-linux-gnu-gfortran"
[[ -x "$fc" ]] || { echo 'matched SDK lacks the Fortran compiler component' >&2; exit 66; }
work=$(mktemp -d /tmp/tdvp-openblas.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
target_flags='-march=rv64imafdc_zicsr_zifencei -mabi=lp64d -O1 -fPIC'
options=(CROSS=1 TARGET=RISCV64_GENERIC BINARY=64 DYNAMIC_ARCH=0
  USE_THREAD=0 USE_LOCKING=1 USE_OPENMP=0
  "HOSTCC=gcc" "CC=$CC --sysroot=$sdk_root/sysroot"
  "FC=$fc --sysroot=$sdk_root/sysroot"
  "AR=$AR" "RANLIB=$RANLIB" "CFLAGS=$target_flags" "FFLAGS=$target_flags"
  "LDFLAGS=-Wl,-rpath-link,$sdk_root/sysroot/usr/lib")
make -C "$source_root" -j"${TDVP_JOBS:-4}" "${options[@]}"
install_root="$work/install"
make -C "$source_root" "${options[@]}" install "PREFIX=$install_root/usr"
# OpenBLAS uses PREFIX rather than DESTDIR; remove that build location from
# its development metadata before sharing it with dependent recipes.
while IFS= read -r -d '' metadata; do
  sed -i "s|$install_root||g" "$metadata"
done < <(find "$install_root/usr" -type f \( -name '*.pc' -o -name '*.cmake' \) -print0)
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$install_root/usr/lib/"libopenblas*.so* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$READELF" "$STRIP" "$payload"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload"
cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
printf '%s\n' "OpenBLAS runtime and development output ready: $payload"
