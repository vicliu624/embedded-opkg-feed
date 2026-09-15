#!/usr/bin/env bash
# Verify that the exact locked SDL archive accepts the reviewed TDVP audio
# policy patch before a games batch spends time cross-compiling its closure.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/sdl2"
cache_root=${TDVP_SDL2_SOURCE_CACHE:-}
cleanup_cache=0
source_tree=
patched_tree=

if [[ -z "$cache_root" ]]; then
  cache_root=$(mktemp -d)
  cleanup_cache=1
fi

cleanup() {
  [[ -z "$source_tree" ]] || rm -rf -- "$source_tree"
  [[ -z "$patched_tree" ]] || rm -rf -- "$patched_tree"
  [[ "$cleanup_cache" -eq 0 ]] || rm -rf -- "$cache_root"
}
trap cleanup EXIT

bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir"
bash "$repo_root/scripts/fetch-source-cache.sh" --cache "$cache_root" --package-dir "$package_dir"

# shellcheck source=/dev/null
source "$repo_root/support/source-archive-library.sh"
source_tree=$(mktemp -d)
patched_tree=$(mktemp -d)
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$source_tree")
cp -a -- "$source_root/." "$patched_tree/"

patch_file="$patched_tree/tdvp-pulseaudio.patch"
sed 's/\r$//' "$package_dir/patches/0001-pulseaudio-add-opt-in-stream-buffer.patch" >"$patch_file"
(
  cd -- "$patched_tree"
  git apply --no-index --check "$patch_file"
  git apply --no-index "$patch_file"
)
grep -Fq 'SDL_AUDIO_PULSEAUDIO_BUFFER_FRAMES' \
  "$patched_tree/src/audio/pulseaudio/SDL_pulseaudio.c"

echo 'SDL2 PulseAudio patch policy: PASS'
