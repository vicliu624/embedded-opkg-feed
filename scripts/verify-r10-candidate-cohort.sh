#!/usr/bin/env bash
# Read-only preflight for the r10 source-candidate cohort. It deliberately
# builds, signs, installs, and publishes nothing; it proves that a supplied
# SDK output and local source cache are eligible inputs for that later work.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  cat >&2 <<'EOF'
usage: verify-r10-candidate-cohort.sh --sdk-root <completed-output/host> [--cache <source-cache>]
EOF
  exit 64
}

sdk_root=
cache_root=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sdk-root) [[ $# -ge 2 ]] || usage; sdk_root=$2; shift 2 ;;
    --cache) [[ $# -ge 2 ]] || usage; cache_root=$2; shift 2 ;;
    *) usage ;;
  esac
done
[[ -n "$sdk_root" ]] || usage

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache_root=${cache_root:-"$repo_root/.tdvp-source-cache"}
[[ -d "$cache_root" && ! -L "$cache_root" ]] || { echo "source cache is not a regular directory: $cache_root" >&2; exit 65; }
cache_root=$(cd -- "$cache_root" && pwd)

# shellcheck source=../support/buildroot-feed-session.sh
source "$repo_root/support/buildroot-feed-session.sh"
# shellcheck source=../support/r10-candidate-cohort.sh
source "$repo_root/support/r10-candidate-cohort.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" '')
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "completed SDK lacks target readelf: $readelf_tool" >&2; exit 66; }

# This is the union of mandatory Kconfig conditions for the r10 cohort. A
# package can still carry a narrower preflight; this script catches a cohort
# mismatch before any Buildroot transaction modifies a temporary config.
for feature in \
  BR2_USE_MMU=y \
  BR2_TOOLCHAIN_HAS_ATOMIC=y \
  BR2_TOOLCHAIN_HAS_THREADS=y \
  BR2_USE_WCHAR=y \
  BR2_ENABLE_LOCALE=y \
  BR2_PACKAGE_NCURSES=y \
  BR2_PACKAGE_READLINE=y \
  BR2_PACKAGE_SQLITE=y \
  BR2_PACKAGE_OPENSSL=y \
  BR2_PACKAGE_LIBOPENSSL=y \
  BR2_PACKAGE_ZLIB=y; do
  grep -Fqx "$feature" "$output/.config" || {
    echo "completed SDK lacks required r10 candidate feature: $feature" >&2
    exit 67
  }
done

for package in "${TDVP_R10_CANDIDATE_COHORT[@]}"; do
  package_dir="$repo_root/packages/$package"
  [[ -d "$package_dir" && -f "$package_dir/source.lock" ]] || {
    echo "r10 candidate package has no source lock: $package" >&2
    exit 68
  }
  while IFS=$'\t' read -r ignored artifact_file artifact_hash ignored_rest; do
    [[ -n "$artifact_file" && "$artifact_hash" =~ ^[0-9a-f]{64}$ && -z "$ignored_rest" ]] || {
      echo "could not parse locked artifact for $package" >&2
      exit 69
    }
    archive="$cache_root/sha256/$artifact_hash/$artifact_file"
    [[ -f "$archive" && ! -L "$archive" ]] || {
      echo "r10 candidate archive is absent from cache: $archive" >&2
      exit 70
    }
    [[ "$(sha256sum "$archive" | awk '{print $1}')" == "$artifact_hash" ]] || {
      echo "r10 candidate archive hash differs in cache: $archive" >&2
      exit 71
    }
  done < <(bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" --emit-artifacts)
done

echo "r10 candidate cohort preflight: PASS ($output)"
