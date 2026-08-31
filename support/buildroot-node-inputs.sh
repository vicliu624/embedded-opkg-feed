#!/usr/bin/env bash
# Build the public libraries which Node 22 is required to link dynamically.
#
# This is deliberately separate from the Node source build.  c-ares, libuv,
# nghttp2 and ICU are ordinary reusable runtimes, not Node private copies.  A
# release-stage marker makes the first requested library build all of them once
# while every IPK still owns only its own public SONAME family.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_prepare_node22_inputs() {
  local package_dir=$1 sdk_root=$2 configured_output=$3
  local output tree install_root stage_root marker
  [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT" ]] || {
    echo 'Node 22 runtime inputs require TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 64
  }
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"

  grep -Fqx 'C_ARES_VERSION = 1.34.2' "$tree/package/c-ares/c-ares.mk" || {
    echo 'locked Buildroot c-ares source differs from the reviewed Node 22 input' >&2
    return 65
  }
  grep -Fqx 'LIBUV_VERSION = 1.50.0' "$tree/package/libuv/libuv.mk" || {
    echo 'locked Buildroot libuv source differs from the reviewed Node 22 input' >&2
    return 66
  }
  grep -Fqx 'NGHTTP2_VERSION = 1.64.0' "$tree/package/nghttp2/nghttp2.mk" || {
    echo 'locked Buildroot nghttp2 source differs from the reviewed Node 22 input' >&2
    return 67
  }
  grep -Fqx 'ICU_VERSION = 73-2' "$tree/package/icu/icu.mk" || {
    echo 'locked Buildroot ICU source differs from the reviewed Node 22 input' >&2
    return 68
  }

  stage_root=$TDVP_FEED_STAGING_ROOT
  marker="$stage_root/.tdvp-node22-inputs-v1"
  if [[ -f "$marker" ]]; then
    grep -Fqx 'c-ares=1.34.2' "$marker" &&
      grep -Fqx 'libuv=1.50.0' "$marker" &&
      grep -Fqx 'nghttp2=1.64.0' "$marker" &&
      grep -Fqx 'icu=73-2' "$marker" || {
        echo 'release staging contains a mismatched Node 22 runtime-input marker' >&2
        return 69
      }
    return 0
  fi

  install_root=$(mktemp -d)
  cleanup_node22_inputs() { rm -rf -- "$install_root"; }
  trap cleanup_node22_inputs RETURN
  tdvp_buildroot_install "$output" "$install_root" \
    --enable BR2_PACKAGE_C_ARES \
    --enable BR2_PACKAGE_LIBUV \
    --enable BR2_PACKAGE_NGHTTP2 \
    --enable BR2_PACKAGE_ICU \
    --target c-ares \
    --target libuv \
    --target nghttp2 \
    --target icu

  for library in \
    libcares.so.2 \
    libuv.so.1 \
    libnghttp2.so.14 \
    libicudata.so.73 \
    libicuuc.so.73 \
    libicui18n.so.73 \
    libicuio.so.73; do
    [[ -e "$install_root/usr/lib/$library" ]] || {
      echo "Node 22 input build omitted public library: $library" >&2
      return 70
    }
  done

  mkdir -p -- "$stage_root/usr/lib"
  cp -a -- "$install_root/usr/lib/libcares.so"* "$stage_root/usr/lib/"
  cp -a -- "$install_root/usr/lib/libuv.so"* "$stage_root/usr/lib/"
  cp -a -- "$install_root/usr/lib/libnghttp2.so"* "$stage_root/usr/lib/"
  cp -a -- "$install_root/usr/lib/libicu"*.so* "$stage_root/usr/lib/"
  cat >"$marker" <<'EOF'
c-ares=1.34.2
libuv=1.50.0
nghttp2=1.64.0
icu=73-2
EOF
}

tdvp_copy_node22_input_library() {
  local package_dir=$1 library_glob=$2
  local stage_root=${TDVP_FEED_STAGING_ROOT:-}
  local payload_dir="$package_dir/root"
  [[ -f "$stage_root/.tdvp-node22-inputs-v1" ]] || {
    echo 'Node 22 runtime inputs were not staged before library packaging' >&2
    return 71
  }
  compgen -G "$stage_root/usr/lib/$library_glob" >/dev/null || {
    echo "staged Node 22 input is missing: $library_glob" >&2
    return 72
  }
  rm -rf -- "$payload_dir"
  mkdir -p -- "$payload_dir/usr/lib"
  cp -a -- "$stage_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
}
