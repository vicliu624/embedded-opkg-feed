#!/usr/bin/env bash
# Confirm that a clean runner can materialize the exact reviewed GBA archive
# before a games candidate spends time restoring or using the SDK toolchain.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/tdvp-gba"
cache_root=${TDVP_GBA_SOURCE_CACHE:-}
cleanup_cache=0

if [[ -z "$cache_root" ]]; then
  cache_root=$(mktemp -d)
  cleanup_cache=1
fi

cleanup() {
  [[ "$cleanup_cache" -eq 0 ]] || rm -rf -- "$cache_root"
}
trap cleanup EXIT

mapfile -t artifacts < <(
  bash "$repo_root/scripts/verify-source-lock.sh" \
    --package-dir "$package_dir" --emit-artifacts
)
[[ ${#artifacts[@]} -eq 1 ]] || {
  echo 'tdvp-gba must declare exactly one reviewed source archive' >&2
  exit 64
}

IFS=$'\t' read -r artifact_url artifact_file artifact_sha256 <<<"${artifacts[0]}"
revision=${artifact_file#cardputer-zero-gameboy-emulator-}
revision=${revision%.tar.gz}
[[ "$revision" =~ ^[0-9a-f]{40}$ ]]
[[ "$artifact_url" == "https://github.com/vicliu624/cardputer-zero-gameboy-emulator/archive/$revision.tar.gz" ]]
[[ "$artifact_file" == "cardputer-zero-gameboy-emulator-$revision.tar.gz" ]]
[[ "$artifact_sha256" == '1f41cccf66a47231298ce727e835813db07829b3e75cc4d654d223f1098b3dc8' ]]

bash "$repo_root/scripts/fetch-source-cache.sh" \
  --cache "$cache_root" --package-dir "$package_dir"

archive="$cache_root/sha256/$artifact_sha256/$artifact_file"
[[ -f "$archive" && ! -L "$archive" ]]
[[ "$(sha256sum "$archive" | awk '{print $1}')" == "$artifact_sha256" ]]

tar -tzf "$archive" | grep -Eq \
  '^cardputer-zero-gameboy-emulator-[0-9a-f]{40}/packaging/tdvp-k230/tdvp-gba$'
tar -tzf "$archive" | grep -Eq \
  '^cardputer-zero-gameboy-emulator-[0-9a-f]{40}/CMakeLists\.txt$'

echo 'tdvp-gba source archive policy: PASS'
