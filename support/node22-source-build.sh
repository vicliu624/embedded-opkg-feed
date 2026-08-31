#!/usr/bin/env bash
# Reproducible source-only Node.js v22.23.2 cross build for TDVP K230.
#
# The K230 target SDK supplies the immutable glibc 2.33 sysroot.  A modern
# Ubuntu RISC-V cross compiler is only a build-host implementation detail:
# output is rejected if it needs a newer GLIBC symbol or a dynamic libstdc++
# than the K230 ABI seed provides.
set -Eeuo pipefail
IFS=$'\n\t'

TDVP_NODE22_VERSION='22.23.2'
TDVP_NODE22_SOURCE_ARCHIVE='node-v22.23.2.tar.gz'
TDVP_NODE22_SOURCE_URL="https://nodejs.org/dist/v${TDVP_NODE22_VERSION}/${TDVP_NODE22_SOURCE_ARCHIVE}"
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
  local source_root=$1
  # Node's V8 build invokes target-width helper ELFs while generating sources.
  # Node v22.23.2's exact, source-locked GYP action sites are changed to run
  # through PRODUCT_DIR/v8-qemu-wrapper.  Each replacement must match exactly
  # once; an upstream source drift therefore fails closed rather than silently
  # building with host executables or an unreviewed patch.
  python3 - "$source_root/node.gyp" "$source_root/tools/v8_gypfiles/v8.gyp" <<'PY'
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
  local stage_root output source_cache archive source_root install_root build_root target_pkg_config
  local cross_cc=${TDVP_NODE22_CC:-riscv64-linux-gnu-gcc}
  local cross_cxx=${TDVP_NODE22_CXX:-riscv64-linux-gnu-g++}
  local qemu=${TDVP_NODE22_QEMU:-qemu-riscv64}
  [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT" ]] || {
    echo 'Node 22 requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 83
  }
  # shellcheck source=../scripts/tdvp-k230-sdk.sh
  source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  tdvp_require_k230_sdk "$sdk_root"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  stage_root=$TDVP_FEED_STAGING_ROOT
  target_pkg_config="$TDVP_K230_HOST_DIR/bin/pkg-config"
  [[ -x "$target_pkg_config" ]] || {
    echo "Node 22 requires the matching Buildroot target pkg-config wrapper: $target_pkg_config" >&2
    return 83
  }

  [[ -f "$stage_root/.tdvp-node22-inputs-v1" ]] || {
    echo 'Node 22 requires separately packaged c-ares, libuv, nghttp2, and ICU inputs' >&2
    return 84
  }
  for required in libcares.so.2 libuv.so.1 libnghttp2.so.14 libicui18n.so.73 libicuuc.so.73 libicudata.so.73; do
    [[ -e "$stage_root/usr/lib/$required" ]] || { echo "Node 22 staging omitted $required" >&2; return 85; }
  done
  for tool in "$cross_cc" "$cross_cxx" "$qemu" curl tar python3 make; do
    command -v "$tool" >/dev/null || { echo "Node 22 build host is missing: $tool" >&2; return 86; }
  done
  local gcc_major
  gcc_major=$($cross_cxx -dumpversion | awk -F. '{print $1}')
  [[ "$gcc_major" =~ ^[0-9]+$ && "$gcc_major" -ge 10 ]] || {
    echo "Node 22 requires a GCC >= 10 build-host cross compiler, got $($cross_cxx -dumpversion)" >&2
    return 87
  }

  if [[ -f "$stage_root/.tdvp-node22-v${TDVP_NODE22_VERSION}" ]]; then
    grep -Fqx "source-commit=${TDVP_NODE22_SOURCE_COMMIT}" "$stage_root/.tdvp-node22-v${TDVP_NODE22_VERSION}" && return 0
    echo 'release staging contains a mismatched Node 22 marker' >&2
    return 88
  fi

  source_cache=${TDVP_NODE22_SOURCE_CACHE:-"$output/../dl"}
  mkdir -p -- "$source_cache"
  archive="$source_cache/$TDVP_NODE22_SOURCE_ARCHIVE"
  if [[ ! -f "$archive" || "$(sha256sum "$archive" | awk '{print $1}')" != "$TDVP_NODE22_SOURCE_SHA256" ]]; then
    rm -f -- "$archive"
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "$archive" "$TDVP_NODE22_SOURCE_URL"
  fi
  printf '%s  %s\n' "$TDVP_NODE22_SOURCE_SHA256" "$archive" | sha256sum -c -

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
  tdvp_node22_patch_qemu_actions "$source_root"
  mkdir -p -- "$source_root/out/Release"
  cat >"$source_root/out/Release/v8-qemu-wrapper" <<EOF
#!/bin/sh
set -eu
exec "$qemu" -L "$TDVP_K230_SYSROOT" "\$@"
EOF
  chmod 0755 "$source_root/out/Release/v8-qemu-wrapper"

  local target_flags target_ldflags
  target_flags="--sysroot=$TDVP_K230_SYSROOT -march=rv64gc -mabi=lp64d -O2 -pipe -fPIC"
  target_ldflags="--sysroot=$TDVP_K230_SYSROOT -Wl,-rpath-link,$TDVP_K230_SYSROOT/usr/lib -static-libstdc++ -static-libgcc"
  if grep -Fqx 'BR2_TOOLCHAIN_HAS_LIBATOMIC=y' "$output/.config"; then
    target_ldflags="$target_ldflags -latomic"
  fi
  (
    cd -- "$source_root"
    export CC="$cross_cc $target_flags"
    export CXX="$cross_cxx $target_flags"
    export AR=riscv64-linux-gnu-ar
    export RANLIB=riscv64-linux-gnu-ranlib
    export LD="$cross_cxx"
    export CC_host=gcc
    export CXX_host=g++
    # system-icu is selected through pkg-config.  Never let configure.py find
    # the x86 runner ICU: all headers and linker paths must resolve through
    # the exact K230 target sysroot populated by Buildroot's ICU recipe.
    export PKG_CONFIG="$target_pkg_config"
    export PKG_CONFIG_SYSROOT_DIR="$TDVP_K230_SYSROOT"
    export PKG_CONFIG_LIBDIR="$TDVP_K230_SYSROOT/usr/lib/pkgconfig:$TDVP_K230_SYSROOT/usr/share/pkgconfig"
    export PKG_CONFIG_PATH=''
    export LDFLAGS="$target_ldflags"
    export PYTHON=python3
    python3 configure.py \
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
    make -j"$(nproc)"
    install_root="$build_root/install-root"
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
  while IFS= read -r -d '' elf; do tdvp_node22_assert_target_elf "$TDVP_K230_READELF" "$elf"; done < <(
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
