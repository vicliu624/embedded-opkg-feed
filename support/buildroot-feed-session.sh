#!/usr/bin/env bash
# Shared, transactional access to the locked Buildroot output used by a TDVP
# feed candidate.  A feed recipe may enable an additional target package, but
# it must leave the completed firmware configuration byte-for-byte unchanged
# when it returns.  This keeps feed work from leaking into the next firmware
# image build.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_buildroot_output_from_sdk() {
  local sdk_root=$1
  local configured_output=${2:-}
  local output
  [[ -d "$sdk_root" ]] || { echo "SDK root does not exist: $sdk_root" >&2; return 64; }
  sdk_root=$(cd -- "$sdk_root" && pwd)
  output=${configured_output:-$(cd -- "$sdk_root/.." && pwd)}
  [[ "$sdk_root" == "$output/host" && -f "$output/.config" && -f "$output/Makefile" && -d "$output/target" ]] || {
    echo 'the feed recipe needs a completed matching Buildroot output directory' >&2
    return 65
  }
  printf '%s\n' "$output"
}

tdvp_buildroot_tree_from_output() {
  local output=$1
  local tree
  tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$output/Makefile")
  [[ -n "$tree" && -d "$tree" && -x "$tree/utils/config" ]] || {
    echo "could not resolve the locked Buildroot tree from $output/Makefile" >&2
    return 66
  }
  printf '%s\n' "$tree"
}

tdvp_assert_buildroot_2025_02_1() {
  local tree=$1
  local version
  version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$tree/Makefile")
  [[ "$version" == '2025.02.1' ]] || {
    echo "expected locked Buildroot 2025.02.1, got ${version:-unknown}" >&2
    return 67
  }
}

# Usage:
#   tdvp_buildroot_install <output> <temporary-target-root> \
#     --enable CONFIG ... --disable CONFIG ... --target package ...
#
# The function runs in a subshell so its EXIT trap cannot affect the recipe
# that called it.  It intentionally dircleans only the requested Buildroot
# packages; stale feed builds are never accepted as evidence for an immutable
# release.
tdvp_buildroot_install() (
  set -Eeuo pipefail
  IFS=$'\n\t'
  local output=$1
  local target_root=$2
  shift 2
  local tree config_backup config_hash config_saved=0 rc
  local -a enable=() disable=() targets=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable)
        [[ $# -ge 2 ]] || { echo '--enable needs a Buildroot symbol' >&2; exit 68; }
        enable+=("$2"); shift 2
        ;;
      --disable)
        [[ $# -ge 2 ]] || { echo '--disable needs a Buildroot symbol' >&2; exit 68; }
        disable+=("$2"); shift 2
        ;;
      --target)
        [[ $# -ge 2 ]] || { echo '--target needs a Buildroot package name' >&2; exit 68; }
        targets+=("$2"); shift 2
        ;;
      *)
        echo "unknown tdvp_buildroot_install option: $1" >&2; exit 68
        ;;
    esac
  done
  [[ ${#targets[@]} -gt 0 ]] || { echo 'tdvp_buildroot_install needs at least one --target' >&2; exit 69; }

  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  config_backup=$(mktemp "$output/.config.tdvp-feed.XXXXXX")
  config_hash=$(sha256sum "$output/.config" | awk '{print $1}')
  cleanup() {
    rc=$?
    set +e
    if [[ "$config_saved" -eq 1 ]]; then
      cp -- "$config_backup" "$output/.config"
      env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
        PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        make -C "$output" olddefconfig || rc=98
      [[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
    fi
    rm -f -- "$config_backup"
    exit "$rc"
  }
  trap cleanup EXIT

  cp -- "$output/.config" "$config_backup"; config_saved=1
  for symbol in "${enable[@]}"; do "$tree/utils/config" --file "$output/.config" --enable "$symbol"; done
  for symbol in "${disable[@]}"; do "$tree/utils/config" --file "$output/.config" --disable "$symbol"; done
  env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
    PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    make -C "$output" olddefconfig
  for symbol in "${enable[@]}"; do grep -Fqx "$symbol=y" "$output/.config" || { echo "Buildroot did not enable $symbol" >&2; exit 70; }; done
  for package in "${targets[@]}"; do
    env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
      PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      make -C "$output" "${package}-dirclean"
    env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
      PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      make -C "$output" TARGET_DIR="$target_root" "${package}-install-target"
  done
)
