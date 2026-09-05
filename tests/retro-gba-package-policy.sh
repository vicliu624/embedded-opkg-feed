#!/usr/bin/env bash
# Static contract for the incremental retro-gba cohort.  The actual K230
# compilation and ELF/closure gates run only in GitHub Actions.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
overlay_helper="$repo_root/scripts/prepare-tdvp-wayland-sdk-overlay.sh"
overlay_source_lock="$repo_root/support/wayland-sdk-overlay-source"

for package in sdl2 sdl2-ttf libmgba tdvp-gba; do
  package_dir="$repo_root/packages/$package"
  test -f "$package_dir/package.env"
  test -f "$package_dir/build.sh"
  test -f "$package_dir/source.lock"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" >/dev/null
  grep -Fq 'tdvp_unpack_locked_source_archive' "$package_dir/build.sh"
done

locked_revision=$(sed -n -E "s/^UPSTREAM_REVISION='([^']+)'$/\1/p" \
  "$repo_root/packages/tdvp-gba/source.lock")
[[ "$locked_revision" =~ ^[0-9a-f]{40}$ ]]
grep -Fqx "SOURCE_REVISION='$locked_revision'" "$repo_root/packages/tdvp-gba/package.env"
if grep -Fq 'not downloadable from its public GitHub archive endpoint' \
  "$repo_root/packages/tdvp-gba/source.lock"; then
  echo 'tdvp-gba source lock still claims the verified public archive is unavailable' >&2
  exit 1
fi

# The SDL patch is a locked input, not an optional best-effort tweak.  Its
# hunk is regenerated for the exact SDL commit and must retain the complete
# FindDeviceName condition so GNU patch can apply it without fuzz on the
# archive unpacked by the GitHub-only K230 build.
sdl2_patch="$repo_root/packages/sdl2/patches/0001-pulseaudio-add-opt-in-stream-buffer.patch"
grep -Fqx "SOURCE_PATCH_1_SHA256='072edf301194f744e9782fd40e2e6bf6b25580af2408c61a42ea25a99d3ed16e'" \
  "$repo_root/packages/sdl2/source.lock"
grep -Fqx '@@ -668,6 +668,34 @@ static int PULSEAUDIO_OpenDevice(_THIS, const char *devname)' "$sdl2_patch"
grep -Fqx '     if (!FindDeviceName(h, iscapture, this->handle)) {' "$sdl2_patch"
grep -Fqx "VERSION='2.30.11-3'" "$repo_root/packages/sdl2/package.env"
grep -Fqx "VERSION='2.22.0-3'" "$repo_root/packages/sdl2-ttf/package.env"
grep -Fqx "PACKAGE_DEPENDS='sdl2 (= 2.30.11-3)'" "$repo_root/packages/sdl2-ttf/package.env"
grep -Fqx "VERSION='0.2.3-4'" "$repo_root/packages/tdvp-gba/package.env"
grep -Fqx "PACKAGE_DEPENDS='sdl2 (= 2.30.11-3), sdl2-ttf (= 2.22.0-3), libmgba (= 0.10.5-1)'" \
  "$repo_root/packages/tdvp-gba/package.env"
grep -Fqx 'libSDL2-2.0.so.0|sdl2|2.30.11-3' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fqx 'libSDL2_ttf-2.0.so.0|sdl2-ttf|2.22.0-3' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

grep -Fq 'retro-gba)' "$workflow"
grep -Fq 'package_args=(--package sdl2-ttf --package tdvp-gba)' "$workflow"
grep -Fq 'expected_packages=(sdl2 sdl2-ttf libmgba tdvp-gba)' "$workflow"
grep -Fq 'if [ "${{ inputs.batch }}" = retro-gba ]; then' "$workflow"
grep -Fq 'bash ./scripts/prepare-tdvp-wayland-sdk-overlay.sh "$build_output" "$overlay_root"' "$workflow"
grep -Fq 'export TDVP_K230_WAYLAND_SDK_OVERLAY="$overlay_root"' "$workflow"
grep -Fq 'export TDVP_REUSE_PUBLISHED_PAYLOADS=0' "$workflow"
grep -Fq 'bash ./tests/retro-gba-package-policy.sh' "$workflow"
grep -Fq "hashFiles('packages/**/source.lock', 'support/wayland-sdk-overlay-source/source.lock')" "$workflow"
grep -Fq 'Populate the locked FreeType development-header source for retro-gba' "$workflow"
grep -Fq 'package-dir ./support/wayland-sdk-overlay-source' "$workflow"
grep -Fq 'export TDVP_K230_WAYLAND_SDK_SOURCE_CACHE="${RUNNER_TEMP}/tdvp-r10-source-cache"' "$workflow"

# A package-only CI restore may retain Buildroot stamps but omit FreeType's
# source-tree headers.  The overlay must then use only the separate source-
# lock cache, with the matching Buildroot SHA-256 verified again; it must
# never fall back to host headers or silently read an arbitrary SDK download.
test -f "$overlay_source_lock/source.lock"
bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$overlay_source_lock" >/dev/null
grep -Fqx "SOURCE_ARTIFACT_1_FILE='freetype-2.13.3.tar.xz'" "$overlay_source_lock/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='0550350666d427c74daeb85d5ac7bb353acba5f76956395995311a9c6f063289'" "$overlay_source_lock/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_URL='https://sources.buildroot.net/freetype/freetype-2.13.3.tar.xz'" "$overlay_source_lock/source.lock"
grep -Fqx "SOURCE_ARTIFACT_2_FILE='wayland-protocols-1.39.tar.xz'" "$overlay_source_lock/source.lock"
grep -Fqx "SOURCE_ARTIFACT_2_SHA256='e1dcdcbbf08e2e0a8a02ee5d9a0be3a6aafc39a4b51fa7e0d2f1a16411cb72fa'" "$overlay_source_lock/source.lock"
grep -Fqx "SOURCE_ARTIFACT_2_URL='https://sources.buildroot.net/wayland-protocols/wayland-protocols-1.39.tar.xz'" "$overlay_source_lock/source.lock"
grep -Fq 'matching Buildroot FreeType SHA-256 is missing' "$overlay_helper"
grep -Fq 'FreeType source archive is missing from locked development source cache' "$overlay_helper"
grep -Fq 'FreeType source archive hash differs from matching Buildroot metadata' "$overlay_helper"
grep -Fq 'archive="$source_cache_root/sha256/$expected_sha/$source_name"' "$overlay_helper"
grep -Fq 'tar -xf "$archive" -C "$freetype_source_temp"' "$overlay_helper"
grep -Fq 'neither host headers nor an undeclared target runtime provider are used' "$overlay_helper"
grep -Fq 'matching Buildroot wayland-protocols SHA-256 is missing' "$overlay_helper"
grep -Fq 'Wayland protocols source archive is missing from locked development source cache' "$overlay_helper"
grep -Fq 'Wayland protocols source archive hash differs from matching Buildroot metadata' "$overlay_helper"
grep -Fq 'tar -xf "$archive" -C "$wayland_protocols_source_temp"' "$overlay_helper"
grep -Fq 'copy_wayland_protocols' "$overlay_helper"
grep -Fq 'find include lib share -type f' "$overlay_helper"
grep -Fq 'share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml' "$repo_root/packages/tdvp-gba/build.sh"
grep -Fq 'verified development overlay' "$repo_root/packages/tdvp-gba/build.sh"
grep -Fq 'share/wayland-protocols/stable/xdg-shell/xdg-shell.xml' "$repo_root/packages/vicliu624-lofibox-widget/build.sh"
# zlib's two public headers are compile-only development inputs.  They must
# come from the matched SDK and must not cause a base runtime library, a host
# header, or made-up pkg-config metadata to enter the overlay.
grep -Fq 'copy_header_file zlib.h' "$overlay_helper"
grep -Fq 'copy_header_file zconf.h' "$overlay_helper"
grep -Fq 'the libz runtime' "$overlay_helper"
if grep -Fq 'copy_link_input z' "$overlay_helper" || grep -Fq 'copy_pc_file zlib' "$overlay_helper"; then
  echo 'Wayland SDK overlay incorrectly materializes the libz runtime development link input' >&2
  exit 1
fi

# Cache identity includes its exact path list.  The merge job must request the
# same SDK cache layout as a package batch, otherwise a matching textual key
# is still a GitHub Actions cache miss before it can validate any IPK.
merge_sdk_restore=$(sed -n \
  '/name: Restore the reviewed SDK base required for closure validation/,/name: Download compatible unsigned batches/p' \
  "$workflow")
grep -Fq 'output/${{ env.TDVP_PROFILE }}/build/**/.stamp_*' <<<"$merge_sdk_restore"

echo 'retro-gba package policy test passed'
