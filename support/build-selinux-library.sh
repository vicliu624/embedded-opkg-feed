#!/usr/bin/env bash
# Standalone userspace libraries. No policy loading, relabeling or service setup.
set -Eeuo pipefail
IFS=$'\n\t'
case "$PACKAGE" in libsepol|libselinux) ;; *) exit 64 ;; esac
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
sdk_root=$4
stage_root=${TDVP_FEED_STAGING_ROOT:?}
[[ -d "$stage_root" && ! -L "$stage_root" ]] || exit 64
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-selinux-build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
python3 "$package_dir/../../support/project-selinux-notices.py" "$source_root" "$PACKAGE"
source "$sdk_root/environment-setup.sh"
options=(CC="$CC" AR="$AR" RANLIB="$RANLIB"
  "CFLAGS=$CFLAGS -fPIC -O1 -I$stage_root/usr/include -ffile-prefix-map=$source_root=/usr/src/$PACKAGE"
  "LDFLAGS=$LDFLAGS -L$stage_root/usr/lib"
  PREFIX=/usr LIBDIR=/usr/lib SHLIBDIR=/usr/lib)
if [[ "$PACKAGE" == libsepol ]]; then
  options+=(DISABLE_CIL=n)
else
  [[ -f "$stage_root/usr/include/sepol/sepol.h" && -f "$stage_root/usr/lib/libsepol.so.2" ]] || {
    echo 'libselinux requires libsepol development staging' >&2; exit 65;
  }
  options+=(PCRE_MODULE=libpcre2-8 'PCRE_CFLAGS=-DUSE_PCRE2 -DPCRE2_CODE_UNIT_WIDTH=8' PCRE_LDLIBS=-lpcre2-8)
fi
make -C "$source_root/src" -j"${TDVP_JOBS:-2}" "${options[@]}"
make -C "$source_root/src" "${options[@]}" DESTDIR="$work/install" install
make -C "$source_root/include" PREFIX=/usr DESTDIR="$work/install" install
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$stage_root/usr"
cp -a "$work/install/usr/lib/$PACKAGE.so."* "$payload_dir/usr/lib/"
cp -a "$work/install/usr/." "$stage_root/usr/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" --license-file LICENSE --license-file TDVP-COPYRIGHT-NOTICE
mkdir -p "$stage_root/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$stage_root/usr/share/licenses/"
printf '%s runtime and development staging ready: %s\n' "$PACKAGE" "$payload_dir"
