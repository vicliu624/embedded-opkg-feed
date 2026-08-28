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
  local header=$1
  [[ -f "$include_source/$header" ]] || die "required header is missing: $header"
  cp -a -- "$include_source/$header" "$temporary/include/$header"
}

copy_header_dir() {
  local directory=$1
  [[ -d "$include_source/$directory" ]] || die "required header directory is missing: $directory"
  cp -a -- "$include_source/$directory" "$temporary/include/$directory"
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
copy_header_dir pulse
copy_header_dir xkbcommon

for pc in wayland-client wayland-cursor wayland-egl xkbcommon alsa libpulse; do
  copy_pc_file "$pc"
done
for library in wayland-client wayland-cursor wayland-egl xkbcommon EGL asound pulse ffi; do
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
