#!/usr/bin/env bash
# Materialise ICU's public runtime libraries for Node.js from its locked
# Buildroot source recipe. ICU needs a host/target two-stage build, so it stays
# on the reviewed Buildroot builder until its dedicated direct-source builder is
# ready. c-ares, libuv, and nghttp2 are intentionally not built here: their
# recipes stage independently built, feed-owned source artifacts.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_prepare_node22_icu_inputs() {
  local package_dir=$1 sdk_root=$2 configured_output=$3
  local output tree install_root stage_root marker download_dir= readelf_tool repo_root
  local -a install_options=() cache_arguments=()
  [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT" && ! -L "$TDVP_FEED_STAGING_ROOT" ]] || {
    echo 'Node ICU runtime input requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 64
  }
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx 'ICU_VERSION = 73-2' "$tree/package/icu/icu.mk" || {
    echo 'locked Buildroot ICU source differs from the reviewed Node 22 input' >&2
    return 65
  }
  readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
  [[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; return 66; }
  TDVP_NODE22_ICU_READELF=$readelf_tool
  export TDVP_NODE22_ICU_READELF

  stage_root=$TDVP_FEED_STAGING_ROOT
  marker="$stage_root/.tdvp-node22-icu-inputs-v1"
  if [[ -f "$marker" ]]; then
    grep -Fqx 'icu=73-2' "$marker" || {
      echo 'release staging contains a mismatched Node 22 ICU runtime-input marker' >&2
      return 67
    }
    return 0
  fi

  if [[ -f "$package_dir/source.lock" ]]; then
    repo_root=$(cd -- "$package_dir/../.." && pwd)
    cache_arguments=(--cache "${TDVP_SOURCE_CACHE_ROOT:-$repo_root/.tdvp-source-cache}" --package-dir "$package_dir")
    [[ "${TDVP_SOURCE_CACHE_OFFLINE:-0}" != 1 ]] || cache_arguments+=(--offline)
    bash "$repo_root/scripts/fetch-source-cache.sh" "${cache_arguments[@]}"
    download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
    install_options+=(--offline-download-dir "$download_dir")
  fi
  install_root=$(mktemp -d)
  cleanup_node22_icu_inputs() {
    local rc=$?
    rm -rf -- "$install_root"
    [[ -z "$download_dir" ]] || rm -rf -- "$download_dir"
    return "$rc"
  }
  trap cleanup_node22_icu_inputs RETURN
  tdvp_buildroot_install "$output" "$install_root" "${install_options[@]}" \
    --enable BR2_PACKAGE_ICU --target icu

  for library in libicudata.so.73 libicuuc.so.73 libicui18n.so.73 libicuio.so.73; do
    [[ -e "$install_root/usr/lib/$library" ]] || {
      echo "Node 22 ICU input build omitted public library: $library" >&2
      return 68
    }
  done
  mkdir -p -- "$stage_root/usr"
  cp -a -- "$install_root/usr/." "$stage_root/usr/"
  cat >"$marker" <<'EOF'
icu=73-2
builder=buildroot-source-lock
EOF
}

tdvp_copy_node22_icu_input_library() {
  local package_dir=$1 library_glob=$2
  local stage_root=${TDVP_FEED_STAGING_ROOT:-} payload_dir elf
  [[ -f "$stage_root/.tdvp-node22-icu-inputs-v1" ]] || {
    echo 'Node 22 ICU runtime input was not staged before library packaging' >&2
    return 69
  }
  compgen -G "$stage_root/usr/lib/$library_glob" >/dev/null || {
    echo "staged Node 22 ICU input is missing: $library_glob" >&2
    return 70
  }
  # shellcheck source=source-archive-library.sh
  source "$package_dir/../../support/source-archive-library.sh"
  # shellcheck source=elf-runtime-policy.sh
  source "$package_dir/../../support/elf-runtime-policy.sh"
  [[ -n "${TDVP_NODE22_ICU_READELF:-}" && -x "$TDVP_NODE22_ICU_READELF" ]] || {
    echo 'Node 22 ICU input has no matching target readelf' >&2
    return 71
  }
  payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
  mkdir -p -- "$payload_dir/usr/lib"
  cp -a -- "$stage_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
  while IFS= read -r -d '' elf; do
    tdvp_remove_elf_runtime_search_paths "$TDVP_NODE22_ICU_READELF" "$elf"
  done < <(find "$payload_dir/usr/lib" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)
}
