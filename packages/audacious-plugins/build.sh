#!/usr/bin/env bash
# Compile only the local GTK3/FFmpeg/ALSA/PulseAudio Audacious module set.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "audacious-plugins does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
support_dir="$feed_root/support/audacious-buildroot"
support_core_dir="$support_dir/tdvp-audacious"
support_plugins_dir="$support_dir/tdvp-audacious-plugins"
sdk_root=$4
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$feed_root/support/buildroot-feed-session.sh"

[[ -d "$sdk_root" && -d "$support_core_dir" && -d "$support_plugins_dir" && -d "${TDVP_FEED_STAGING_ROOT:-}" ]] || { echo 'audacious-plugins needs the core/plugin staging roots and matching Buildroot SDK' >&2; exit 66; }
sdk_root=$(cd -- "$sdk_root" && pwd)
build_output=${TDVP_AUDACIOUS_BUILDROOT_OUTPUT:-$(cd -- "$sdk_root/.." && pwd)}
[[ "$sdk_root" == "$build_output/host" && -f "$build_output/.config" && -f "$build_output/Makefile" && -d "$build_output/target" ]] || { echo 'TDVP_AUDACIOUS_BUILDROOT_OUTPUT must be a completed matching Buildroot output' >&2; exit 67; }
buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree" && -x "$buildroot_tree/utils/config" ]] || { echo 'could not resolve the locked Buildroot tree from the SDK output' >&2; exit 68; }
actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == '2025.02.1' ]] || { echo "expected Buildroot 2025.02.1, got ${actual_buildroot_version:-unknown}" >&2; exit 69; }
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$support_plugins_dir/tdvp-audacious-plugins.hash" || { echo 'Audacious plugin source checksum does not match the reviewed Buildroot package input' >&2; exit 70; }
buildroot_staging_source="$build_output/host/riscv64-buildroot-linux-gnu/sysroot"
[[ -d "$buildroot_staging_source" ]] || { echo "Audacious plugins need the SDK Buildroot staging sysroot: $buildroot_staging_source" >&2; exit 70; }

staged_core_package="$buildroot_tree/package/tdvp-audacious"
staged_plugins_package="$buildroot_tree/package/tdvp-audacious-plugins"
config_file="$buildroot_tree/package/Config.in"
config_backup=$(mktemp "$build_output/.config.tdvp-audacious-plugins.XXXXXX")
config_old_backup=
package_config_backup=$(mktemp "$buildroot_tree/package/Config.in.tdvp-audacious-plugins.XXXXXX")
install_root=$(mktemp -d)
buildroot_staging_root=$(mktemp -d)
download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
payload_dir="$package_dir/root"
config_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
config_old_hash=
config_saved=0
config_old_saved=0
package_config_saved=0
core_package_staged=0
plugins_package_staged=0

cleanup() {
  local rc=$?
  set +e
  if [[ "$package_config_saved" -eq 1 ]]; then cp -- "$package_config_backup" "$config_file"; fi
  if [[ "$config_saved" -eq 1 ]]; then
    # Restore the caller-owned Kconfig inputs byte-for-byte.  A cleanup-time
    # olddefconfig could normalize the completed SDK configuration instead of
    # returning the exact state that this temporary feed-only package found.
    cp --preserve=mode,timestamps -- "$config_backup" "$build_output/.config" || rc=98
    [[ "$(sha256sum "$build_output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
    if [[ "$config_old_saved" -eq 1 ]]; then
      cp --preserve=mode,timestamps -- "$config_old_backup" "$build_output/.config.old" || rc=100
      [[ "$(sha256sum "$build_output/.config.old" | awk '{print $1}')" == "$config_old_hash" ]] || rc=101
    elif [[ -e "$build_output/.config.old" || -L "$build_output/.config.old" ]]; then
      rm -f -- "$build_output/.config.old" || rc=102
    fi
  fi
  if [[ "$plugins_package_staged" -eq 1 ]]; then rm -rf -- "$staged_plugins_package"; fi
  if [[ "$core_package_staged" -eq 1 ]]; then rm -rf -- "$staged_core_package"; fi
  rm -f -- "$config_backup" "$config_old_backup" "$package_config_backup"
  rm -rf -- "$install_root" "$buildroot_staging_root" "$download_dir"
  exit "$rc"
}
trap cleanup EXIT

[[ ! -e "$staged_core_package" ]] || { echo "refusing to replace existing Buildroot package: $staged_core_package" >&2; exit 71; }
[[ ! -e "$staged_plugins_package" ]] || { echo "refusing to replace existing Buildroot package: $staged_plugins_package" >&2; exit 71; }
cp -- "$build_output/.config" "$config_backup"; config_saved=1
if [[ -e "$build_output/.config.old" || -L "$build_output/.config.old" ]]; then
  [[ -f "$build_output/.config.old" && ! -L "$build_output/.config.old" ]] || { echo 'Buildroot config backup is not a regular file' >&2; exit 73; }
  config_old_backup=$(mktemp "$build_output/.config.old.tdvp-audacious-plugins.XXXXXX")
  cp --preserve=mode,timestamps -- "$build_output/.config.old" "$config_old_backup"
  config_old_hash=$(sha256sum "$build_output/.config.old" | awk '{print $1}')
  config_old_saved=1
fi
cp -- "$config_file" "$package_config_backup"; package_config_saved=1
cp -a -- "$support_core_dir" "$staged_core_package"; core_package_staged=1
cp -a -- "$support_plugins_dir" "$staged_plugins_package"; plugins_package_staged=1
printf '\nsource "package/tdvp-audacious/Config.in"\nsource "package/tdvp-audacious-plugins/Config.in"\n' >>"$config_file"
# The plugin must see audacious.pc and development libraries, but neither may
# persist in the platform SDK. Use an isolated copy that is discarded in the
# transaction cleanup rather than modifying the caller's staging sysroot.
cp -a --reflink=auto "$buildroot_staging_source/." "$buildroot_staging_root/"

"$buildroot_tree/utils/config" --file "$build_output/.config" --enable BR2_PACKAGE_TDVP_AUDACIOUS --enable BR2_PACKAGE_TDVP_AUDACIOUS_PLUGINS
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y make -C "$build_output" olddefconfig
grep -qx 'BR2_PACKAGE_TDVP_AUDACIOUS=y' "$build_output/.config"
grep -qx 'BR2_PACKAGE_TDVP_AUDACIOUS_PLUGINS=y' "$build_output/.config"
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y STAGING_DIR="$buildroot_staging_root" make -C "$build_output" tdvp-audacious-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y STAGING_DIR="$buildroot_staging_root" make -C "$build_output" tdvp-audacious-plugins-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y STAGING_DIR="$buildroot_staging_root" make -C "$build_output" TARGET_DIR="$install_root" tdvp-audacious-plugins-install-target

[[ -d "$install_root/usr/lib/audacious" ]] || { echo 'Audacious plugin install did not create /usr/lib/audacious' >&2; exit 72; }
find "$install_root/usr/lib/audacious" -type f -name '*.so' -print -quit | grep -q . || { echo 'Audacious plugin install did not produce dynamic modules' >&2; exit 73; }
test -s "$buildroot_staging_root/usr/lib/pkgconfig/audacious.pc"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/lib"
cp -a -- "$install_root/usr/lib/audacious" "$payload_dir/usr/lib/"
source_version=${VERSION%-*}
install -Dm 0644 "$build_output/build/tdvp-audacious-plugins-$source_version/COPYING" "$payload_dir/usr/share/licenses/audacious-plugins/COPYING"
echo "audacious-plugins payload ready: $payload_dir"
