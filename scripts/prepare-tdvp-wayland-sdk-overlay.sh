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
# matching completed firmware build remains the authoritative fallback: use
# its one FreeType build tree only when the sysroot/target roots do not expose
# the required development files.  This keeps the overlay ABI-bound and does
# not synthesise headers or metadata from the build host.
header_sources=("$include_source" "$sysroot/usr/include" "$build_root/target/usr/include")
freetype_build_dir=
find_freetype_build_dir() {
  [[ -n "$freetype_build_dir" ]] && return 0
  local -a matches=()
  shopt -s nullglob
  matches=("$build_root"/build/freetype-*)
  shopt -u nullglob
  [[ ${#matches[@]} -eq 1 && -d "${matches[0]}" ]] || {
    die 'the SDK and target roots omit FreeType development files, and the completed firmware build has no unique build/freetype-* fallback'
  }
  freetype_build_dir=${matches[0]}
  [[ -d "$freetype_build_dir/include/freetype" && -f "$freetype_build_dir/include/ft2build.h" ]] || {
    die "FreeType fallback has incomplete public headers: $freetype_build_dir"
  }
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
cleanup() { rm -rf -- "$temporary"; }
trap cleanup EXIT
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
trap - EXIT
printf 'TDVP SDK bridge: created firmware-matched Wayland overlay: %s\n' "$overlay"
