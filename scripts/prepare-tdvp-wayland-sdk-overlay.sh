#!/usr/bin/env bash
# Export only the development view of the exact TDVP firmware output that an
# ABI-bound feed package needs.  The generated directory is deliberately not
# a second sysroot and is never installed into an .ipk: target programs keep
# resolving these SONAMEs from the base firmware.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  cat >&2 <<'EOF'
usage: prepare-tdvp-wayland-sdk-overlay.sh <buildroot-output> <new-overlay-directory>

<buildroot-output> is the profile directory containing host/, target/, and
.config from the TDVP firmware build.  The destination must not already exist.
EOF
}

die() {
  printf 'TDVP SDK bridge: %s\n' "$*" >&2
  exit 1
}

[[ $# -eq 2 ]] || { usage; exit 64; }

build_root=$(cd -- "$1" && pwd)
overlay_input=$2
[[ -d "$build_root/host" && -d "$build_root/target" ]] || \
  die "not a completed Buildroot profile output: $build_root"

overlay_parent=$(cd -- "$(dirname -- "$overlay_input")" && pwd)
overlay_name=$(basename -- "$overlay_input")
[[ "$overlay_name" != '.' && "$overlay_name" != '..' ]] || die 'invalid overlay directory name'
overlay="$overlay_parent/$overlay_name"
[[ ! -e "$overlay" ]] || die "refusing to replace an existing overlay: $overlay"

# Both directories are owned by this invocation.  Keeping the FreeType source
# extraction separate from the overlay makes it impossible for source-only
# build inputs to be published as SDK overlay files.
temporary=
freetype_source_temp=
cleanup() {
  local status=$?
  [[ -z "$temporary" || ! -e "$temporary" ]] || rm -rf -- "$temporary"
  [[ -z "$freetype_source_temp" || ! -e "$freetype_source_temp" ]] || \
    rm -rf -- "$freetype_source_temp"
  return "$status"
}
trap cleanup EXIT

toolchain_file=$(find "$build_root/host" -type f \
  -path '*/share/buildroot/toolchainfile.cmake' -print -quit)
[[ -n "$toolchain_file" && -f "$toolchain_file" ]] || \
  die 'Buildroot CMake toolchain file is missing'
sysroot=$(find "$build_root/host" -type d -name sysroot -print -quit)
[[ -n "$sysroot" && -d "$sysroot/usr" ]] || die 'Buildroot target sysroot is missing'

include_source="$sysroot/usr/include"
if [[ ! -f "$include_source/wayland-client.h" ]]; then
  include_source="$build_root/target/usr/include"
fi
[[ -f "$include_source/wayland-client.h" ]] || die 'Wayland client headers are missing'

# Buildroot's SDK sysroot includes the development view of most firmware
# libraries, but strips FreeType's public headers from this profile.  The
# matching completed firmware build remains the authoritative fallback.  A
# package-only SDK cache may preserve its build stamps without preserving those
# headers, so the fallback can additionally extract headers from the exact
# FreeType source archive in the dedicated, source-lock-verified cache.  The
# archive digest is also verified against the matching Buildroot source tree;
# neither host headers nor an undeclared target runtime provider are used.
header_sources=("$include_source" "$sysroot/usr/include" "$build_root/target/usr/include")
freetype_build_dir=
extract_freetype_source_headers() {
  local sdk_workspace source_cache_root package_mk hash_file version source_name expected_sha archive actual_sha
  local source_root
  local -a package_mks=() source_roots=()

  sdk_workspace=$(cd -- "$build_root/../.." && pwd)
  mapfile -t package_mks < <(
    find "$sdk_workspace/output" -type f -path '*/package/freetype/freetype.mk' -print |
      LC_ALL=C sort
  )
  [[ ${#package_mks[@]} -eq 1 ]] || die \
    'the SDK and target roots omit FreeType development files, and the restored SDK has no unique Buildroot FreeType package definition'

  package_mk=${package_mks[0]}
  hash_file=${package_mk%.mk}.hash
  [[ -f "$hash_file" ]] || die "matching Buildroot FreeType hash file is missing: $hash_file"
  version=$(sed -nE \
    's/^FREETYPE_VERSION[[:space:]]*=[[:space:]]*([0-9]+([.][0-9]+)*)[[:space:]]*$/\1/p' \
    "$package_mk")
  [[ "$version" =~ ^[0-9]+([.][0-9]+)*$ ]] || die \
    "matching Buildroot FreeType version is invalid: $package_mk"

  source_name="freetype-$version.tar.xz"
  expected_sha=$(awk -v source="$source_name" \
    '$1 == "sha256" && $3 == source && length($2) == 64 && $2 ~ /^[0-9a-f]+$/ { print $2; exit }' \
    "$hash_file")
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || die \
    "matching Buildroot FreeType SHA-256 is missing: $hash_file"

  source_cache_root=${TDVP_K230_WAYLAND_SDK_SOURCE_CACHE:-}
  [[ -n "$source_cache_root" && -d "$source_cache_root" && ! -L "$source_cache_root" ]] || die \
    'the SDK and target roots omit FreeType development files, and the required locked development-header source cache is unavailable'
  archive="$source_cache_root/sha256/$expected_sha/$source_name"
  [[ -f "$archive" && ! -L "$archive" ]] || die \
    "FreeType source archive is missing from locked development source cache: $archive"
  actual_sha=$(sha256sum "$archive" | awk '{print $1}')
  [[ "$actual_sha" == "$expected_sha" ]] || die \
    "FreeType source archive hash differs from matching Buildroot metadata: $archive"

  freetype_source_temp=$(mktemp -d "$overlay_parent/.${overlay_name}.freetype-source.XXXXXX")
  tar -xf "$archive" -C "$freetype_source_temp"
  mapfile -t source_roots < <(
    find "$freetype_source_temp" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort
  )
  [[ ${#source_roots[@]} -eq 1 ]] || die \
    "verified FreeType source archive has an unexpected layout: $archive"
  source_root=${source_roots[0]}
  [[ -d "$source_root/include/freetype" && -f "$source_root/include/ft2build.h" ]] || die \
    "verified FreeType source archive lacks public headers: $archive"
  freetype_build_dir=$source_root
}

find_freetype_build_dir() {
  [[ -n "$freetype_build_dir" ]] && return 0
  local -a matches=()
  shopt -s nullglob
  matches=("$build_root"/build/freetype-*)
  shopt -u nullglob
  if [[ ${#matches[@]} -eq 1 && -d "${matches[0]}" && \
    -d "${matches[0]}/include/freetype" && -f "${matches[0]}/include/ft2build.h" ]]; then
    freetype_build_dir=${matches[0]}
    return 0
  fi
  extract_freetype_source_headers
}

has_freetype_headers=0
for directory in "${header_sources[@]}"; do
  if [[ -d "$directory/freetype" && -f "$directory/ft2build.h" ]]; then
    has_freetype_headers=1
    break
  fi
done
if [[ "$has_freetype_headers" -eq 0 ]]; then
  find_freetype_build_dir
  header_sources+=("$freetype_build_dir/include")
fi

pc_sources=(
  "$sysroot/usr/lib/pkgconfig"
  "$sysroot/usr/share/pkgconfig"
  "$build_root/target/usr/lib/pkgconfig"
  "$build_root/target/usr/share/pkgconfig"
)
lib_sources=(
  "$sysroot/usr/lib"
  "$build_root/target/usr/lib"
  "$build_root/target/usr/lib/lp64d"
  "$build_root/target/lib"
  "$build_root/target/lib64/lp64d"
)

temporary=$(mktemp -d "$overlay_parent/.${overlay_name}.tmp.XXXXXX")
mkdir -p "$temporary/include" "$temporary/lib/pkgconfig"

copy_header_file() {
  local header=$1 source='' directory
  for directory in "${header_sources[@]}"; do
    if [[ -f "$directory/$header" ]]; then
      source="$directory/$header"
      break
    fi
  done
  [[ -n "$source" ]] || die "required header is missing: $header"
  cp -a -- "$source" "$temporary/include/$header"
}

copy_header_dir() {
  local header_dir=$1 source='' directory
  for directory in "${header_sources[@]}"; do
    if [[ -d "$directory/$header_dir" ]]; then
      source="$directory/$header_dir"
      break
    fi
  done
  [[ -n "$source" ]] || die "required header directory is missing: $header_dir"
  cp -a -- "$source" "$temporary/include/$header_dir"
}

copy_pc_file() {
  local pc=$1 source=''
  local directory
  for directory in "${pc_sources[@]}"; do
    if [[ -f "$directory/$pc.pc" ]]; then
      source="$directory/$pc.pc"
      break
    fi
  done
  if [[ -z "$source" && "$pc" == freetype2 ]]; then
    find_freetype_build_dir
    source=$(find "$freetype_build_dir" -type f -name 'freetype2.pc' -print | LC_ALL=C sort | sed -n '1p')
  fi
  [[ -n "$source" ]] || die "required pkg-config metadata is missing: $pc.pc"
  cp -a -- "$source" "$temporary/lib/pkgconfig/$pc.pc"
}

copy_link_input() {
	local library=$1 soname="lib$1.so" source='' directory resolved_directory candidate base
	for directory in "${lib_sources[@]}"; do
		[[ -d "$directory" ]] || continue
		# K230's lp64d compatibility directory is commonly a symlink back to
		# ../lib.  `find -L` treats that as a directory and reports a loop,
		# which made the SDK bridge fail before a feed package could build.
		# Resolve each candidate directory once, then inspect only its direct
		# entries.  An unversioned linker input may itself be a symlink, so
		# check it directly and let `cp -L` below materialize the real file.
		resolved_directory=$(readlink -f -- "$directory" 2>/dev/null || true)
		[[ -n "$resolved_directory" && -d "$resolved_directory" ]] || continue
		if [[ -e "$resolved_directory/$soname" ]]; then
			candidate="$resolved_directory/$soname"
		else
			candidate=$(find -P "$resolved_directory" -maxdepth 1 -type f \
				-name "$soname.*" -print | LC_ALL=C sort | sed -n '1p')
		fi
		if [[ -n "$candidate" ]]; then
			source="$candidate"
			break
    fi
  done
	[[ -n "$source" ]] || die "firmware link input is missing: $soname"
	base=$(basename -- "$source")
	if [[ "$base" == "$soname" ]]; then
		cp -L -- "$source" "$temporary/lib/$base"
	else
		cp -L -- "$source" "$temporary/lib/$base"
		ln -s "$base" "$temporary/lib/$soname"
  fi
}

copy_header_file wayland-client.h
copy_header_file wayland-client-core.h
copy_header_file wayland-client-protocol.h
copy_header_file wayland-util.h
copy_header_dir EGL
copy_header_dir alsa
copy_header_dir freetype
copy_header_dir pulse
copy_header_dir xkbcommon
copy_header_file ft2build.h

for pc in wayland-client wayland-cursor wayland-egl xkbcommon alsa libpulse freetype2; do
  copy_pc_file "$pc"
done
for library in wayland-client wayland-cursor wayland-egl xkbcommon EGL asound pulse ffi freetype; do
  copy_link_input "$library"
done

# Headers copied from the verified source archive are development-only staging
# inputs.  Remove their extraction tree before the overlay is finalised.
if [[ -n "$freetype_source_temp" ]]; then
  rm -rf -- "$freetype_source_temp"
  freetype_source_temp=
fi

{
  printf 'tdvp_sdk_bridge=1\n'
  printf 'buildroot_output=%s\n' "$build_root"
  printf 'toolchain_file=%s\n' "$toolchain_file"
  printf 'target_sysroot=%s\n' "$sysroot"
  printf 'firmware_config_sha256=%s\n' "$(sha256sum "$build_root/.config" | awk '{print $1}')"
} > "$temporary/tdvp-sdk-overlay.manifest"
(
  cd "$temporary"
  find include lib -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS
)

mv -- "$temporary" "$overlay"
temporary=
trap - EXIT
printf 'TDVP SDK bridge: created firmware-matched Wayland overlay: %s\n' "$overlay"
