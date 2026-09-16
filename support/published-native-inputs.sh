#!/usr/bin/env bash
set -Eeuo pipefail

tdvp_sdk_host_python() (
  local package_dir=$1 destination=$2 work archive
  if [[ -x "$destination/bin/python3.13" ]]; then return 0; fi
  source "$package_dir/../../support/source-archive-library.sh"
  archive=$(tdvp_source_archive_locked_file "$package_dir" Python-3.13.3.tar.xz)
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  tar -xf "$archive" -C "$work"
  cd "$work/Python-3.13.3"
  env -u CC -u CXX -u CFLAGS -u CPPFLAGS -u LDFLAGS ./configure --prefix="$destination" --without-ensurepip
  make -j"${TDVP_JOBS:-$(nproc)}"
  make install
)

tdvp_sdk_icu_inputs() (
  local package_dir=$1 sdk_root=$2 stage=$TDVP_FEED_STAGING_ROOT
  local work source_root native="$stage/.tdvp-native/icu" marker="$stage/.tdvp-node22-icu-inputs-v1"
  if [[ -f "$marker" ]]; then return 0; fi
  source "$package_dir/../../support/source-archive-library.sh"
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work")
  # ICU needs native generators from the same locked source as its target libs.
  # Retain this native build for Node's host V8 generators in this transaction.
  mkdir -p "$native/build" "$native/source"
  cp -a "$source_root/source/." "$native/source/"
  (
    cd "$native/build"
    env -u CC -u CXX -u AR -u RANLIB -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
      "$native/source/configure" --prefix="$native" --disable-tests --disable-samples
    make -j"${TDVP_JOBS:-$(nproc)}"
    make install
  )
  (
    source "$sdk_root/environment-setup.sh"
    cd "$source_root/source"
    ./configure --host=riscv64-unknown-linux-gnu --prefix=/usr \
      --with-cross-build="$native/build" --disable-tests --disable-samples --disable-static
    make -j"${TDVP_JOBS:-$(nproc)}"
    make DESTDIR="$stage" install
  )
  printf 'icu=73-2\nbuilder=published-sdk-source-lock\n' >"$marker"
)
