#!/usr/bin/env bash
# Materialise one public archive-library SONAME from the locked Buildroot
# source.  The caller gives a single component instead of copying a bulk
# archive runtime: each reusable non-ABI library keeps one explicit IPK owner.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_build_archive_library() {
  local package_dir=$1
  local sdk_root=$2
  local configured_output=$3
  local config_symbol=$4
  local buildroot_package=$5
  local library_glob=$6
  local expected_source_line=$7
  local output install_root payload_dir

  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  local tree
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx "$expected_source_line" "$tree/package/$buildroot_package/${buildroot_package}.mk" || {
    echo "locked Buildroot source differs from reviewed $buildroot_package recipe" >&2
    return 71
  }

  install_root=$(mktemp -d)
  payload_dir="$package_dir/root"
  cleanup_archive_library() { rm -rf -- "$install_root"; }
  trap cleanup_archive_library RETURN
  tdvp_buildroot_install "$output" "$install_root" \
    --enable "$config_symbol" --target "$buildroot_package"
  compgen -G "$install_root/usr/lib/$library_glob" >/dev/null || {
    echo "$buildroot_package target install omitted $library_glob" >&2
    return 72
  }
  rm -rf -- "$payload_dir"
  mkdir -p -- "$payload_dir/usr/lib"
  cp -a "$install_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
  echo "$(basename "$package_dir") payload ready: $payload_dir"
}
