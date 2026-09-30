#!/usr/bin/env bash
# Keep target-owned SONAMEs as byte-identical catalogue providers.  A matching
# source recipe is deferred only with an explicit package/version attestation.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
catalogue="$repo_root/scripts/build-runtime-catalog.sh"
build_all="$repo_root/scripts/build-all.sh"
runtime_closure="$repo_root/scripts/verify-runtime-closure.sh"

grep -Fq 'target_provider_manifest="$output_dir/.tdvp-target-runtime-packages.tsv"' "$catalogue"
grep -Fq 'package_manifest="$output_dir/.tdvp-runtime-catalog-packages.tsv"' "$catalogue"
grep -Fq "printf '%s|%s\\n' \"\$package\" \"\$version\" >>\"\$package_manifest\"" "$catalogue"
grep -Fq 'target provider package collides with an un-attested target SONAME:' "$catalogue"
grep -Fq 'target_provider_version[$soname]=$version' "$catalogue"
grep -Fq 'target_package_sonames[$package]+="$soname"' "$catalogue"
grep -Fq 'register_runtime_needed_owner()' "$catalogue"
grep -Fq 'filename=${source##*/}' "$catalogue"
grep -Fq 'recovered transitional image ownership from Buildroot records:' "$catalogue"
grep -Fq 'for current_root, _, files in os.walk(build_dir):' "$catalogue"
grep -Fq 'if ".files-list.txt" not in files:' "$catalogue"
grep -Fq 'if len(owners) == 1:' "$catalogue"
grep -Fq 'no verified image-provider aliases were derived from target ownership' "$catalogue"
grep -Fq 'declare -A image_path_present=()' "$catalogue"
grep -Fq 'data_image_alias[$package]=tdvp-image-base' "$catalogue"
grep -Fq 'runtime data path is absent from the locked image inventory:' "$catalogue"
grep -Fq "printf '%s|%s\\n' \"\$package\" \"\${data_image_alias[\$package]}\" >>\"\$image_provider_map\"" "$catalogue"
grep -Fq 'TDVP_IMAGE_PROVIDER_MANIFEST' "$catalogue"
grep -Fq 'IMAGE_OWNERSHIP_MANIFEST_SHA256' "$catalogue"
grep -Fq '[[ -s "$image_provider_map" ]]' "$build_all"
grep -Fq "IMAGE_OWNERSHIP_MANIFEST_SHA256='0c0d0f2f4b1a2cb5e1278939bc17143f2b76b5654e26dc1648b274ba41f79cb6'" "$repo_root/platforms/tdvp-k230-r1/platform.env"
grep -Fq 'options: [archive, audacious-foundation, audacious-core, audacious-plugins, audacious-app, audacious, network-tools, netsurf, media, games, desktop-tools, development-tools, nodejs]' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'netsurf)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'package_args=(--package tdvp-netsurf)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'expected_packages=(tdvp-netsurf)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'media)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'package_args=(--package tdvp-mpv)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'games)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'package_args=(--package sdl2 --package sdl2-ttf --package libmgba --package tdvp-gba)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'copy_header_file zlib.h' "$repo_root/scripts/prepare-tdvp-wayland-sdk-overlay.sh"
grep -Fq 'copy_wayland_protocols' "$repo_root/scripts/prepare-tdvp-wayland-sdk-overlay.sh"
grep -Fq 'share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml' "$repo_root/scripts/tdvp-k230-sdk.sh"
grep -Fq 'locked FreeType source archive digest differs' "$repo_root/scripts/prepare-tdvp-wayland-sdk-overlay.sh"
! grep -Fq 'freetype-dirclean freetype' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'Verify provider alternatives in the target-runtime base' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'verify-image-provider-alternatives.sh' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'include-hidden-files: true' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
test -f "$repo_root/tests/tdvp-gba-source-archive-policy.sh"
grep -Fq 'Preflight the reviewed GBA source archive' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'TDVP_GBA_SOURCE_CACHE: ${{ runner.temp }}/tdvp-r11-source-cache' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
test -f "$repo_root/tests/sdl2-pulseaudio-patch-policy.sh"
grep -Fq 'Preflight the reviewed SDL2 PulseAudio patch' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'TDVP_SDL2_SOURCE_CACHE: ${{ runner.temp }}/tdvp-r11-source-cache' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'runtime-${{ env.TDVP_RUNTIME_BASE_CACHE_SCHEMA }}-' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
incoming_root_assignment='incoming_root="${RUNNER_TEMP}/tdvp-r11-incoming"'
[[ "$(grep -Fc "$incoming_root_assignment" "$repo_root/.github/workflows/build-r10-batch-candidate.yml")" -ge 2 ]]
grep -Fq 'install -m 0644 "$provider_map" "$feed_dir/.tdvp-image-runtime-providers.tsv"' \
  "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
merged_upload=$(sed -n '/name: tdvp-k230-r11-merged-unsigned-/,/include-hidden-files: true/p' \
  "$repo_root/.github/workflows/build-r10-batch-candidate.yml")
grep -Fq 'include-hidden-files: true' <<<"$merged_upload"
grep -Fq 'runtime_verification=$(mktemp -d)' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'cp -a -- "$runtime_feed/." "$runtime_verification/"' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq 'bash ./scripts/make-index.sh "$runtime_verification"' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq -- '--provider-map "$runtime_verification/.tdvp-image-runtime-providers.tsv"' "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
test -f "$repo_root/scripts/compose-signed-feed-overlay.sh"
test -f "$repo_root/scripts/verify-image-provider-alternatives.sh"
grep -Fq '/usr/libexec/vicliu-pocket-linux-hardware/vpl-hardwared' "$repo_root/platforms/tdvp-k230-r1/runtime-data-packages.tsv"
grep -Fq 'build_generated_package "$package" "$description" "$root" "$runtime_version"' "$catalogue"
grep -Fq 'target_runtime_provider_manifest="$feed_dir/.tdvp-target-runtime-packages.tsv"' "$build_all"
grep -Fq 'runtime_catalogue_package_manifest="$feed_dir/.tdvp-runtime-catalog-packages.tsv"' "$build_all"
grep -Fq 'assert_runtime_catalogue_package()' "$build_all"
grep -Fq 'runtime_catalogue_package[$package]=1' "$build_all"
grep -Fq '[[ -n "$runtime_catalogue_package_manifest" && -s "$runtime_catalogue_package_manifest" ]] || return 0' "$build_all"
grep -Fq 'source recipe deferred; runtime catalogue already provides:' "$build_all"
if grep -Fq '[[ "$reuse_runtime_catalog" -eq 1 ]] || return 0' "$build_all"; then
  echo 'runtime catalogue package deferral must apply to both freshly generated and reused catalogues' >&2
  exit 1
fi
grep -Fq 'source runtime recipe deferred; target owns' "$build_all"
for ownership in \
  'libz.so.1|libz|1.3.1-1' \
  'libncursesw.so.6|libncursesw|6.4-20230603-1' \
  'libreadline.so.8|libreadline|8.2-1' \
  'libpcre2-8.so.0|libpcre2-8|10.44-1' \
  'libpopt.so.0|libpopt|1.19-1'; do
  grep -Fqx "$ownership" "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
done
# The extra-owner table is the canonical provider identity for libraries whose
# package name cannot safely be inferred from a SONAME.  The catalogue must
# load those overrides before build-all defers matching source recipes.
grep -Fq 'done <"$extra_owner_manifest"' "$catalogue"
# A complete image ownership manifest can leave the optional extra-owner map
# empty.  Bash expands an empty associative-array key list to one empty line;
# the catalogue must discard that line before using it as an array key.
grep -Fq '[[ -n "$soname" ]] || continue' "$catalogue"
grep -Fq 'There is no package key for that record.' "$catalogue"
grep -Fq 'PACKAGE_SOURCE_STAGING' "$build_all"
grep -Fq 'PACKAGE_SDK_DEVELOPMENT_DEPENDS' "$build_all"
grep -Fq 'PACKAGE_SDK_DEVELOPMENT_FILES' "$build_all"
grep -Fq 'validate_sdk_development_dependencies()' "$build_all"
grep -Fq 'source staging recipe retained; target owns final runtime' "$build_all"
grep -Fq 'sole final runtime IPK provider for that package name' "$build_all"
grep -Fq 'PACKAGE_SOURCE_STAGING=0' "$repo_root/packages/libcurl-4/package.env"
grep -Fq "PACKAGE_SDK_DEVELOPMENT_FILES='usr/include/curl/curl.h usr/lib/pkgconfig/libcurl.pc usr/lib/libcurl.so usr/bin/curl-config'" "$repo_root/packages/libcurl-4/package.env"
grep -Fq "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libz libssl-3 libcrypto-3 libexpat-1 libpcre2-8 libcurl-4'" "$repo_root/packages/git-runtime/package.env"
grep -Fq "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libreadline'" "$repo_root/packages/gawk/package.env"
grep -Fqx "PACKAGE_SDK_DEVELOPMENT_DEPENDS='libncursesw'" "$repo_root/packages/dialog/package.env"
grep -Fqx "PACKAGE_SDK_DEVELOPMENT_FILES='usr/include/curses.h usr/lib/pkgconfig/ncursesw.pc usr/lib/libncursesw.so'" "$repo_root/packages/libncursesw/package.env"
grep -Fq 'package_build_depends=${package_build_depends//,/ }' "$build_all"
grep -Fq 'target runtime provider version is not attested for' "$build_all"
grep -Fq '[[ -n "${target_runtime_provider[$dependency]:-}" && "${source_staging_provider[$dependency]:-0}" != 1 ]] && continue' "$build_all"
grep -Fq '"$feed_dir/.tdvp-target-runtime-packages.tsv"' "$build_all"
grep -Fq 'empty dynamic-string value is represented by readelf as []' \
  "$repo_root/support/elf-runtime-policy.sh"
grep -Fq "grep -Ev '\\[[[:space:]]*\\]'" "$repo_root/support/elf-runtime-policy.sh"
grep -Fq 'assert_elf_runtime_search_path_policy()' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'retains a byte-identical target RPATH/RUNPATH' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'cmp -s -- "$elf" "$base_elf"' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'top-level /usr/lib/lib*.so* provider with no DT_SONAME' "$runtime_closure"
grep -Fq 'runtime provider name $provider_name is supplied by both' "$runtime_closure"
grep -Fq 'find "$library_root" -maxdepth 1 -type f -name '\''lib*.so*'\'' -print' "$runtime_closure"

echo 'target runtime provider deferral policy: PASS'

grep -Fq "uses: ./.github/actions/published-sdk" "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fq "TDVP_RUNTIME_BASE_CACHE_SCHEMA: published-r11-v1" "$repo_root/.github/workflows/build-r10-batch-candidate.yml"
