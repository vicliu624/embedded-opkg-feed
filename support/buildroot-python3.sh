#!/usr/bin/env bash
# Build the selected Python runtime exactly once in the locked Buildroot
# output, place only Python's files in the release staging tree, and let the
# three feed packages split public libpython, stdlib/extensions, and the CLI.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_build_python3_to_stage() {
  local package_dir=$1 sdk_root=$2 configured_output=$3
  local output tree install_root stage_root
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx 'PYTHON3_VERSION_MAJOR = 3.13' "$tree/package/python3/python3.mk" || {
    echo 'locked K230 Buildroot Python major version differs from reviewed r9 recipe' >&2
    return 72
  }
  grep -Fqx 'PYTHON3_VERSION = $(PYTHON3_VERSION_MAJOR).3' "$tree/package/python3/python3.mk" || {
    echo 'locked K230 Buildroot Python patch version differs from reviewed r9 recipe' >&2
    return 73
  }
  install_root=$(mktemp -d)
  cleanup_python3() { rm -rf -- "$install_root"; }
  trap cleanup_python3 RETURN
  tdvp_buildroot_install "$output" "$install_root" \
    --enable BR2_PACKAGE_PYTHON3 \
    --enable BR2_PACKAGE_PYTHON3_PY_PYC \
    --enable BR2_PACKAGE_PYTHON3_BZIP2 \
    --enable BR2_PACKAGE_PYTHON3_CURSES \
    --enable BR2_PACKAGE_PYTHON3_DECIMAL \
    --enable BR2_PACKAGE_PYTHON3_READLINE \
    --enable BR2_PACKAGE_PYTHON3_SSL \
    --enable BR2_PACKAGE_PYTHON3_SQLITE \
    --enable BR2_PACKAGE_PYTHON3_PYEXPAT \
    --enable BR2_PACKAGE_PYTHON3_XZ \
    --enable BR2_PACKAGE_PYTHON3_ZLIB \
    --target python3
  [[ -x "$install_root/usr/bin/python3" && -d "$install_root/usr/lib/python3.13" && -e "$install_root/usr/lib/libpython3.13.so.1.0" ]] || {
    echo 'Python target install omitted the interpreter, standard library, or public libpython SONAME' >&2
    return 74
  }
  stage_root=${TDVP_FEED_STAGING_ROOT:-}
  [[ -n "$stage_root" ]] || { echo 'Python build needs TDVP_FEED_STAGING_ROOT' >&2; return 75; }
  mkdir -p "$stage_root/usr/bin" "$stage_root/usr/lib"
  cp -a "$install_root/usr/bin/python" "$install_root/usr/bin/python3" "$stage_root/usr/bin/"
  cp -a "$install_root/usr/lib/libpython3.13.so"* "$stage_root/usr/lib/"
  cp -a "$install_root/usr/lib/python3.13" "$stage_root/usr/lib/python3.13"
}
