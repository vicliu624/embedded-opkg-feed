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

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, nodejs]' "$workflow"
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
grep -Fq 'matching Buildroot FreeType SHA-256 is missing' "$overlay_helper"
grep -Fq 'FreeType source archive is missing from locked development source cache' "$overlay_helper"
grep -Fq 'FreeType source archive hash differs from matching Buildroot metadata' "$overlay_helper"
grep -Fq 'archive="$source_cache_root/sha256/$expected_sha/$source_name"' "$overlay_helper"
grep -Fq 'tar -xf "$archive" -C "$freetype_source_temp"' "$overlay_helper"
grep -Fq 'neither host headers nor an undeclared target runtime provider are used' "$overlay_helper"

# Cache identity includes its exact path list.  The merge job must request the
# same SDK cache layout as a package batch, otherwise a matching textual key
# is still a GitHub Actions cache miss before it can validate any IPK.
merge_sdk_restore=$(sed -n \
  '/name: Restore the reviewed SDK base required for closure validation/,/name: Download compatible unsigned batches/p' \
  "$workflow")
grep -Fq 'output/${{ env.TDVP_PROFILE }}/build/**/.stamp_*' <<<"$merge_sdk_restore"

echo 'retro-gba package policy test passed'
