#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
sdk_root=$4
tdvp_require_k230_sdk "$sdk_root"
[[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 64
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-kerberos-build.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
mkdir "$work/source" "$work/build"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
source "$sdk_root/environment-setup.sh"
IFS=' ' read -r -a compiler_args <<< "$CC"
IFS=' ' read -r -a compiler_flags <<< "$CFLAGS"
# Configure cache answers require actual target execution with this SDK.
for test in sdk-constructor-destructor-smoke sdk-printf-positional-smoke; do
  "${compiler_args[@]}" "${compiler_flags[@]}" "$package_dir/../../tests/$test.c" -o "$work/$test"
  timeout 30 qemu-riscv64 -L "$TDVP_K230_SYSROOT" "$work/$test"
done
export CPPFLAGS="-I$TDVP_K230_SYSROOT/usr/include"
export LDFLAGS="-L$TDVP_K230_SYSROOT/usr/lib -Wl,-rpath-link,$TDVP_K230_SYSROOT/usr/lib"
(
  cd "$work/build"
  krb5_cv_attr_constructor_destructor=yes ac_cv_printf_positional=yes "$source_root/src/configure" \
    --host=riscv64-unknown-linux-gnu --build="$(gcc -dumpmachine)" --prefix=/usr --libdir=/usr/lib \
    --enable-shared --disable-static --disable-rpath --with-system-et COMPILE_ET="$(command -v compile_et)"
  make -j"${TDVP_JOBS:-2}"
  make DESTDIR="$work/install" install
)
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr"
for library in "$work/install/usr/lib/"lib*.so.[0-9]*; do
  cp -a "$library" "$payload_dir/usr/lib/"
done
if [[ -d "$work/install/usr/lib/krb5" ]]; then
  cp -a "$work/install/usr/lib/krb5" "$payload_dir/usr/lib/"
fi
# Development export includes krb5-config; no service/config files enter the IPK.
cp -a "$work/install/usr/include" "$TDVP_FEED_STAGING_ROOT/usr/"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/lib" "$TDVP_FEED_STAGING_ROOT/usr/bin"
cp -a "$work/install/usr/lib/." "$TDVP_FEED_STAGING_ROOT/usr/lib/"
cp -a "$work/install/usr/bin/krb5-config" "$TDVP_FEED_STAGING_ROOT/usr/bin/"
tdvp_assert_direct_archive_elfs "$TDVP_K230_READELF" "$TDVP_K230_STRIP" "$payload_dir"
python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" --license-file NOTICE --license-file README
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
printf 'Kerberos library payload ready: %s\n' "$payload_dir"
