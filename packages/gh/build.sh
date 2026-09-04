#!/usr/bin/env bash
# Cross-build GitHub CLI from its locked source and a derived, hash-verified
# Go vendor bundle. No target binary or Go module is fetched during the final
# build: GOPROXY is deliberately disabled once the bundle has been admitted
# to TDVP's content-addressed cache.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
# shellcheck source=../../support/go-module-vendor-cache.sh
source "$package_dir/../../support/go-module-vendor-cache.sh"
# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

tdvp_require_k230_sdk "$sdk_root"
tdvp_load_go_module_vendor_lock "$package_dir"
source_archive=$(tdvp_source_archive_locked_file "$package_dir" "$SOURCE_ARCHIVE")

work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-gh-source-build.XXXXXX")
payload_dir=
payload_ready=0
root_link="$package_dir/root"
cleanup() {
  local rc=$?
  rm -rf -- "$work_root"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$root_link" && "$(readlink -f -- "$root_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$root_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tar -xzf "$source_archive" -C "$work_root"
source_root="$work_root/$SOURCE_DIRECTORY"
[[ -d "$source_root" && ! -L "$source_root" && -f "$source_root/go.mod" && -f "$source_root/go.sum" ]] || {
  echo "locked gh source archive did not unpack as expected: $source_root" >&2
  exit 65
}

go_binary=$(tdvp_prepare_locked_go_host_toolchain "$package_dir" "$work_root")
vendor_cache=$(tdvp_prepare_go_module_vendor_cache "$source_root" "$go_binary" "$work_root")
tdvp_extract_go_module_vendor_cache "$source_root" "$vendor_cache"

target_binary="$work_root/gh"
empty_module_cache="$work_root/empty-go-module-cache"
go_build_cache="$work_root/go-build-cache"
mkdir -p -- "$empty_module_cache" "$go_build_cache"
(
  cd -- "$source_root"
  env \
    GOTOOLCHAIN=local \
    GOMODCACHE="$empty_module_cache" \
    GOCACHE="$go_build_cache" \
    GOPROXY=off \
    GOSUMDB=off \
    GONOSUMDB='*' \
    GOFLAGS='-mod=vendor' \
    GOOS=linux \
    GOARCH=riscv64 \
    CGO_ENABLED=0 \
    "$go_binary" build -trimpath -buildvcs=false -ldflags='-s -w' -o "$target_binary" ./cmd/gh
)
[[ -f "$target_binary" && ! -L "$target_binary" ]] || {
  echo 'Go did not produce the gh target binary' >&2
  exit 66
}
"$TDVP_K230_READELF" -h "$target_binary" | grep -Fq 'Machine:                           RISC-V' || {
  echo 'gh target binary is not RISC-V' >&2
  exit 67
}
if "$TDVP_K230_READELF" -dW "$target_binary" 2>/dev/null | grep -F 'Shared library:'; then
  echo 'gh must remain a self-contained Go target binary; unexpected dynamic dependency' >&2
  exit 68
fi
"$TDVP_K230_STRIP" --strip-unneeded "$target_binary"
tdvp_assert_elf_without_runtime_search_path "$TDVP_K230_READELF" "$target_binary"

payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
install -Dm 0755 "$target_binary" "$payload_dir/usr/bin/gh"
"$TDVP_K230_READELF" -h "$payload_dir/usr/bin/gh" | grep -Fq 'Machine:                           RISC-V' || {
  echo 'gh payload is not RISC-V' >&2
  exit 69
}
tdvp_assert_elf_without_runtime_search_path "$TDVP_K230_READELF" "$payload_dir/usr/bin/gh"
payload_ready=1
echo "gh source-built offline payload ready: $payload_dir"
