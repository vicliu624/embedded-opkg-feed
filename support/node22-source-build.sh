#!/usr/bin/env bash
# Reproducible source-only Node.js v22.23.2 cross build for TDVP K230.
#
# The matching K230 SDK supplies the immutable glibc 2.33 sysroot and target
# compiler by default. An explicitly selected external cross compiler remains
# a build-host implementation detail: output is rejected if it needs a newer
# GLIBC symbol or a dynamic libstdc++ than the K230 ABI seed provides.
set -Eeuo pipefail
IFS=$'\n\t'

# Node's own install target embeds $ORIGIN RPATH entries in the target binary.
# Feed payloads rely on declared SONAME ownership instead, so the shared ELF
# policy removes those entries before staging and verifies their absence.
# shellcheck source=elf-runtime-policy.sh
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/elf-runtime-policy.sh"

TDVP_NODE22_VERSION='22.23.2'
TDVP_NODE22_SOURCE_ARCHIVE='node-v22.23.2.tar.gz'
TDVP_NODE22_SOURCE_SHA256='cdaed46fcd8923a55974b7bbc7caaadeaaf7aed60cc137e59837b72f575ef641'
TDVP_NODE22_SOURCE_COMMIT='aa4c77582be995286fc6e00aaf530dc7ade102a9'

tdvp_node22_assert_glibc_floor() {
  local readelf_tool=$1 elf=$2 version major minor
  while IFS= read -r version; do
    [[ "$version" =~ ^GLIBC_([0-9]+)\.([0-9]+)$ ]] || continue
    major=${BASH_REMATCH[1]}
    minor=${BASH_REMATCH[2]}
    if (( major > 2 || (major == 2 && minor > 33) )); then
      echo "Node 22 output needs unsupported $version: $elf" >&2
      return 80
    fi
  done < <("$readelf_tool" --version-info "$elf" 2>/dev/null | grep -oE 'GLIBC_[0-9]+\.[0-9]+' | LC_ALL=C sort -u || true)
}

tdvp_node22_assert_target_elf() {
  local readelf_tool=$1 elf=$2
  "$readelf_tool" -h "$elf" | grep -Fq 'Machine:                           RISC-V' || {
    echo "Node 22 output is not a RISC-V ELF: $elf" >&2
    return 81
  }
  tdvp_node22_assert_glibc_floor "$readelf_tool" "$elf"
  if "$readelf_tool" -d "$elf" 2>/dev/null | grep -Eq 'Shared library: \[(libstdc\+\+\.so\.6|libgcc_s\.so\.1)\]'; then
    echo "Node 22 output dynamically imports a non-K230 C++ runtime: $elf" >&2
    return 82
  fi
}

tdvp_node22_patch_qemu_actions() {
  local source_root=$1 host_python=$2
  # Node's V8 build invokes target-width helper ELFs while generating sources.
  # Node v22.23.2's exact, source-locked GYP action sites are changed to run
  # through PRODUCT_DIR/v8-qemu-wrapper.  Each replacement must match exactly
  # once; an upstream source drift therefore fails closed rather than silently
  # building with host executables or an unreviewed patch.
  "$host_python" - "$source_root/node.gyp" "$source_root/tools/v8_gypfiles/v8.gyp" <<'PY'
from pathlib import Path
import sys

node = Path(sys.argv[1])
v8 = Path(sys.argv[2])

def replace_once(path: Path, old: str, new: str) -> None:
    data = path.read_text(encoding='utf-8')
    count = data.count(old)
    if count != 1:
        raise SystemExit(f"expected one locked Node 22.23.2 GYP context in {path}: {old!r}; got {count}")
    path.write_text(data.replace(old, new, 1), encoding='utf-8')

wrapper = "                    '<(PRODUCT_DIR)/v8-qemu-wrapper',\n"
replace_once(node,
    "                    '<(node_mksnapshot_exec)',\n                    '<(node_snapshot_main)',\n",
    wrapper + "                    '<(node_mksnapshot_exec)',\n                    '<(node_snapshot_main)',\n")
replace_once(node,
    "                    '<(node_mksnapshot_exec)',\n                    '--build-snapshot',\n",
    wrapper + "                    '<(node_mksnapshot_exec)',\n                    '--build-snapshot',\n")
replace_once(node,
    "                  'inputs': [\n                    '<(node_mksnapshot_exec)',\n                  ],\n                  'outputs': [\n                    '<(SHARED_INTERMEDIATE_DIR)/node_snapshot.cc',\n                  ],\n                  'action': [\n                    '<@(_inputs)',\n",
    "                  'inputs': [\n" + wrapper + "                    '<(node_mksnapshot_exec)',\n                  ],\n                  'outputs': [\n                    '<(SHARED_INTERMEDIATE_DIR)/node_snapshot.cc',\n                  ],\n                  'action': [\n                    '<@(_inputs)',\n")
replace_once(node,
    "          'inputs': [\n            '<(node_js2c_exec)',\n            '<@(library_files)',\n",
    "          'inputs': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(node_js2c_exec)',\n            '<@(library_files)',\n")
replace_once(node,
    "          'action': [\n            '<(node_js2c_exec)',\n            '<@(_outputs)',\n",
    "          'action': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(node_js2c_exec)',\n            '<@(_outputs)',\n")

replace_once(v8,
    "          'inputs': [  # Order matters.\n            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)torque<(EXECUTABLE_SUFFIX)',\n",
    "          'inputs': [  # Order matters.\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)torque<(EXECUTABLE_SUFFIX)',\n")
replace_once(v8,
    "          'action': [\n            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)torque<(EXECUTABLE_SUFFIX)',\n",
    "          'action': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)torque<(EXECUTABLE_SUFFIX)',\n")
replace_once(v8,
    "          'inputs': [\n            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)bytecode_builtins_list_generator<(EXECUTABLE_SUFFIX)',\n          ],\n          'outputs': [\n            '<(generate_bytecode_builtins_list_output)',\n",
    "          'inputs': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)bytecode_builtins_list_generator<(EXECUTABLE_SUFFIX)',\n          ],\n          'outputs': [\n            '<(generate_bytecode_builtins_list_output)',\n")
replace_once(v8,
    "          'inputs': [\n            '<(mksnapshot_exec)',\n          ],\n          'outputs': [\n            '<(INTERMEDIATE_DIR)/snapshot.cc',\n",
    "          'inputs': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(mksnapshot_exec)',\n          ],\n          'outputs': [\n            '<(INTERMEDIATE_DIR)/snapshot.cc',\n")
replace_once(v8,
    "          'inputs': [\n            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)gen-regexp-special-case<(EXECUTABLE_SUFFIX)',\n          ],\n          'outputs': [\n            '<(SHARED_INTERMEDIATE_DIR)/src/regexp/special-case.cc',\n",
    "          'inputs': [\n" + "            '<(PRODUCT_DIR)/v8-qemu-wrapper',\n" + "            '<(PRODUCT_DIR)/<(EXECUTABLE_PREFIX)gen-regexp-special-case<(EXECUTABLE_SUFFIX)',\n          ],\n          'outputs': [\n            '<(SHARED_INTERMEDIATE_DIR)/src/regexp/special-case.cc',\n")
PY
}

tdvp_build_node22_to_stage() {
  local package_dir=$1 sdk_root=$2 configured_output=$3
  local stage_root output archive source_root install_root build_root target_pkg_config input_marker jobs host_python node_patch
  local host_cc host_cxx host_cc_major host_cxx_major host_icu_root host_icu_libdir host_uv_build host_uv_library
  local cross_cc=${TDVP_NODE22_CC:-} cross_cxx=${TDVP_NODE22_CXX:-}
  local cross_ar=${TDVP_NODE22_AR:-} cross_ranlib=${TDVP_NODE22_RANLIB:-}
  local qemu=${TDVP_NODE22_QEMU:-}
  [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT" ]] || {
    echo 'Node 22 requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 83
  }
  # shellcheck source=../scripts/tdvp-k230-sdk.sh
  source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  # shellcheck source=source-archive-library.sh
  source "$package_dir/../../support/source-archive-library.sh"
  tdvp_require_k230_sdk "$sdk_root"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  cross_cc=${cross_cc:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-gcc"}
  cross_cxx=${cross_cxx:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-g++"}
  cross_ar=${cross_ar:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-gcc-ar"}
  cross_ranlib=${cross_ranlib:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-gcc-ranlib"}
  host_python=${TDVP_NODE22_HOST_PYTHON:-"$TDVP_K230_HOST_DIR/bin/python3.13"}
  host_cc=${TDVP_NODE22_HOST_CC:-$(command -v gcc-10 2>/dev/null || command -v gcc)}
  host_cxx=${TDVP_NODE22_HOST_CXX:-$(command -v g++-10 2>/dev/null || command -v g++)}
  if [[ -z "$qemu" ]]; then
    qemu=$(command -v qemu-riscv64 2>/dev/null || true)
    [[ -n "$qemu" ]] || qemu=/opt/tdvp-qemu/qemu-riscv64-static
  fi
  stage_root=$TDVP_FEED_STAGING_ROOT
  target_pkg_config="$TDVP_K230_HOST_DIR/bin/pkg-config"
  [[ -x "$target_pkg_config" ]] || {
    echo "Node 22 requires the matching Buildroot target pkg-config wrapper: $target_pkg_config" >&2
    return 83
  }

  for input_marker in libcares libuv libnghttp2; do
    [[ -f "$stage_root/.tdvp-direct-source-$input_marker" ]] || {
      echo "Node 22 requires direct-source staging for $input_marker" >&2
      return 84
    }
  done
  [[ -f "$stage_root/.tdvp-node22-icu-inputs-v1" ]] || {
    echo 'Node 22 requires separately staged ICU inputs' >&2
    return 84
  }
  host_icu_root="$output/build/host-icu-73-2/source"
  host_icu_libdir="$host_icu_root/lib"
  for required in "$host_icu_root/common/unicode/utypes.h" \
    "$host_icu_libdir/libicui18n.so" "$host_icu_libdir/libicuuc.so" "$host_icu_libdir/libicudata.so"; do
    [[ -e "$required" ]] || { echo "Node 22 requires the matching Buildroot host ICU 73.2 input: $required" >&2; return 85; }
  done
  for required in libcares.so.2 libuv.so.1 libnghttp2.so.14 libicui18n.so.73 libicuuc.so.73 libicudata.so.73; do
    [[ -e "$stage_root/usr/lib/$required" ]] || { echo "Node 22 staging omitted $required" >&2; return 85; }
  done
  for tool in "$cross_cc" "$cross_cxx" "$cross_ar" "$cross_ranlib" "$qemu" "$host_python" "$host_cc" "$host_cxx" tar make patch cmake; do
    command -v "$tool" >/dev/null || { echo "Node 22 build host is missing: $tool" >&2; return 86; }
  done
  jobs=${TDVP_JOBS:-$(nproc)}
  [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || {
    echo "TDVP_JOBS must be a positive integer: $jobs" >&2
    return 86
  }
  "$host_python" --version | grep -Eq '^Python 3\.(8|9|1[0-9])\.' || {
    echo "Node 22 requires a Python >= 3.8 host generator: $host_python" >&2
    return 86
  }
  local gcc_major
  gcc_major=$($cross_cxx -dumpversion | awk -F. '{print $1}')
  [[ "$gcc_major" =~ ^[0-9]+$ && "$gcc_major" -ge 10 ]] || {
    echo "Node 22 requires a GCC >= 10 build-host cross compiler, got $($cross_cxx -dumpversion)" >&2
    return 87
  }
  host_cc_major=$($host_cc -dumpversion | awk -F. '{print $1}')
  host_cxx_major=$($host_cxx -dumpversion | awk -F. '{print $1}')
  [[ "$host_cc_major" =~ ^[0-9]+$ && "$host_cc_major" -ge 10 && \
     "$host_cxx_major" =~ ^[0-9]+$ && "$host_cxx_major" -ge 10 ]] || {
    echo "Node 22 requires native GCC/G++ >= 10 for V8 host generators, got $($host_cc -dumpversion) / $($host_cxx -dumpversion)" >&2
    return 87
  }

  if [[ -f "$stage_root/.tdvp-node22-v${TDVP_NODE22_VERSION}" ]]; then
    grep -Fqx "source-commit=${TDVP_NODE22_SOURCE_COMMIT}" "$stage_root/.tdvp-node22-v${TDVP_NODE22_VERSION}" && return 0
    echo 'release staging contains a mismatched Node 22 marker' >&2
    return 88
  fi

  archive=$(tdvp_source_archive_locked_file "$package_dir")
  [[ "$(basename -- "$archive")" == "$TDVP_NODE22_SOURCE_ARCHIVE" && \
     "$(sha256sum "$archive" | awk '{print $1}')" == "$TDVP_NODE22_SOURCE_SHA256" ]] || {
    echo 'Node 22 source.lock does not match the reviewed source archive' >&2
    return 89
  }

  build_root=$(mktemp -d)
  cleanup_node22() { rm -rf -- "$build_root"; }
  trap cleanup_node22 RETURN
  tar -xzf "$archive" -C "$build_root"
  source_root="$build_root/node-v${TDVP_NODE22_VERSION}"
  [[ -d "$source_root/.git" ]] && {
    echo 'Node release source archive unexpectedly contains an unchecked-out VCS directory' >&2
    return 89
  }
  grep -Fqx "#define NODE_MODULE_VERSION 127" "$source_root/src/node_version.h" || {
    echo 'Node v22.23.2 source no longer has the reviewed module ABI 127' >&2
    return 90
  }
  node_patch="$package_dir/patches/node22-lazy-bz2-import.patch"
  patch --batch --forward -d "$source_root" -p1 <"$node_patch" || {
    echo 'Node 22 host-Python compatibility patch did not apply to the locked source' >&2
    return 90
  }
  tdvp_node22_patch_qemu_actions "$source_root" "$host_python"
  host_uv_build="$build_root/host-libuv"
  mkdir -p -- "$host_uv_build"
  (
    cd -- "$host_uv_build"
    cmake "$source_root/deps/uv" \
      -DCMAKE_C_COMPILER="$host_cc" \
      -DCMAKE_CXX_COMPILER="$host_cxx" \
      -DLIBUV_BUILD_SHARED=OFF \
      -DLIBUV_BUILD_TESTS=OFF \
      -DCMAKE_BUILD_TYPE=Release
    cmake --build . -- -j"$jobs"
  )
  host_uv_library="$host_uv_build/libuv.a"
  [[ -f "$host_uv_library" ]] || { echo "Node 22 host libuv build omitted $host_uv_library" >&2; return 90; }
  mkdir -p -- "$source_root/out/Release"
  cat >"$source_root/out/Release/v8-qemu-wrapper" <<EOF
#!/bin/sh
set -eu
if "$TDVP_K230_READELF" -h "\$1" 2>/dev/null | grep -Fq 'RISC-V'; then
  exec "$qemu" -L "$TDVP_K230_SYSROOT" "\$@"
fi
export LD_LIBRARY_PATH="$host_icu_libdir"
exec "\$@"
EOF
  chmod 0755 "$source_root/out/Release/v8-qemu-wrapper"

  local target_flags target_ldflags
  # Keep target-only include paths on the cross compiler command.  Node/V8
  # invokes native generators through CC_host/CXX_host; a global CPPFLAGS
  # would make those host tools parse the RISC-V sysroot headers.
  target_flags="--sysroot=$TDVP_K230_SYSROOT -I$stage_root/usr/include -march=rv64gc -mabi=lp64d -O2 -pipe -fPIC"
  target_ldflags="--sysroot=$TDVP_K230_SYSROOT -Wl,-rpath-link,$TDVP_K230_SYSROOT/usr/lib -static-libstdc++ -static-libgcc"
  if grep -Fqx 'BR2_TOOLCHAIN_HAS_LIBATOMIC=y' "$output/.config"; then
    target_ldflags="$target_ldflags -latomic"
  fi
  # This path is inspected after the build sub-shell exits.  Define it in the
  # function scope rather than assigning it beside `make install`, otherwise
  # `set -u` rejects the post-install ELF audit even after installation worked.
  install_root="$build_root/install-root"
  (
    cd -- "$source_root"
    export CC="$cross_cc $target_flags"
    export CXX="$cross_cxx $target_flags"
    export AR="$cross_ar"
    export RANLIB="$cross_ranlib"
    export LD="$cross_cxx"
    export CC_host="$host_cc"
    export CXX_host="$host_cxx"
    # c-ares, libuv and nghttp2 come from this release's source-built staging
    # sysroot. ICU's separately locked Buildroot two-stage input is staged
    # alongside them. Keep the immutable SDK sysroot only as the ABI baseline
    # for zlib/OpenSSL and libc, never as a substitute for these feed owners.
    export PKG_CONFIG="$target_pkg_config"
    # pkg-config cflags are emitted into common GYP rules that V8 also uses
    # for native generator tools.  Scope those paths to the candidate staging
    # sysroot: cross CC/CXX still receive the immutable SDK sysroot explicitly,
    # while host tools never ingest RISC-V libc headers.
    export PKG_CONFIG_SYSROOT_DIR="$stage_root"
    export PKG_CONFIG_LIBDIR="$stage_root/usr/lib/pkgconfig:$stage_root/usr/share/pkgconfig:$TDVP_K230_SYSROOT/usr/lib/pkgconfig:$TDVP_K230_SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_PATH=''
    export CPPFLAGS=''
    export LDFLAGS="$target_ldflags -L$stage_root/usr/lib -Wl,-rpath-link,$stage_root/usr/lib -L$TDVP_K230_SYSROOT/usr/lib"
    export PYTHON="$host_python"
    # V8's host-side generators consume ICU data.  The matching x86_64 ICU is
    # produced by the same locked Buildroot ICU source transaction, while the
    # RISC-V target toolset gets its ICU headers/libraries only from staging.
    export TDVP_NODE22_HOST_ICU_INCLUDE="$host_icu_root/common:$host_icu_root/i18n"
    export TDVP_NODE22_HOST_ICU_LIBRARIES="-L$host_icu_libdir -licui18n -licuuc -licudata"
    export TDVP_NODE22_HOST_LIBUV_LIBRARIES="$host_uv_library -ldl -lrt"
    export LD_LIBRARY_PATH="$host_icu_libdir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    "$host_python" configure.py \
      --prefix=/usr \
      --dest-os=linux \
      --dest-cpu=riscv64 \
      --cross-compiling \
      --ninja \
      --shared \
      --shared-zlib \
      --shared-cares \
      --shared-libuv \
      --shared-nghttp2 \
      --shared-openssl \
      --with-intl=system-icu
    # GNU make jobserver exports a bare `-j` in MAKEFLAGS on this host. Node's
    # generated Makefile forwards that literal flag to Ninja unless JOBS is
    # explicit, so pass the validated build concurrency in both interfaces.
    make -j"$jobs" JOBS="$jobs"
    make install DESTDIR="$install_root"
  )
  [[ -x "$install_root/usr/bin/node" && -e "$install_root/usr/lib/libnode.so.127" ]] || {
    echo 'Node 22 target install omitted node or libnode.so.127' >&2
    return 91
  }
  [[ -d "$install_root/usr/lib/node_modules/npm" ]] || {
    echo 'Node 22 target install omitted bundled npm runtime' >&2
    return 92
  }
  [[ -x "$install_root/usr/bin/npm" && -x "$install_root/usr/bin/npx" ]] || {
    echo 'Node 22 target install omitted npm/npx frontends' >&2
    return 93
  }
  while IFS= read -r -d '' elf; do
    # The Node installation contains executable JavaScript Corepack shims as
    # well as target ELF files. Only ELF payloads participate in architecture,
    # dynamic-linker, and RPATH policy checks.
    "$TDVP_K230_READELF" -h "$elf" >/dev/null 2>&1 || continue
    tdvp_remove_elf_runtime_search_paths "$TDVP_K230_READELF" "$elf"
    tdvp_node22_assert_target_elf "$TDVP_K230_READELF" "$elf"
    tdvp_assert_elf_without_runtime_search_path "$TDVP_K230_READELF" "$elf"
  done < <(
    find "$install_root/usr/bin" "$install_root/usr/lib" -type f \( -perm -u+x -o -name '*.so*' \) -print0 | LC_ALL=C sort -z
  )
  mkdir -p -- "$stage_root/usr"
  cp -a -- "$install_root/usr/." "$stage_root/usr/"
  cat >"$stage_root/.tdvp-node22-v${TDVP_NODE22_VERSION}" <<EOF
source-commit=${TDVP_NODE22_SOURCE_COMMIT}
source-sha256=${TDVP_NODE22_SOURCE_SHA256}
target-glibc-max=2.33
EOF
}
