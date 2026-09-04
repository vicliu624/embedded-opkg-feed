#!/usr/bin/env bash
# Build the Audacious core once through the locked Buildroot profile.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "audacious-core does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
support_dir="$feed_root/support/audacious-buildroot"
support_core_dir="$support_dir/tdvp-audacious"
sdk_root=$4
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$feed_root/support/buildroot-feed-session.sh"

[[ -d "$sdk_root" && -d "$support_core_dir" ]] || { echo 'audacious-core needs the matching Buildroot SDK and core support files' >&2; exit 66; }
sdk_root=$(cd -- "$sdk_root" && pwd)
build_output=${TDVP_AUDACIOUS_BUILDROOT_OUTPUT:-$(cd -- "$sdk_root/.." && pwd)}
[[ "$sdk_root" == "$build_output/host" && -f "$build_output/.config" && -f "$build_output/Makefile" && -d "$build_output/target" ]] || { echo 'TDVP_AUDACIOUS_BUILDROOT_OUTPUT must be a completed matching Buildroot output' >&2; exit 67; }
buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree" && -x "$buildroot_tree/utils/config" ]] || { echo 'could not resolve the locked Buildroot tree from the SDK output' >&2; exit 68; }
actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == '2025.02.1' ]] || { echo "expected Buildroot 2025.02.1, got ${actual_buildroot_version:-unknown}" >&2; exit 69; }
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$support_core_dir/tdvp-audacious.hash" || { echo 'Audacious source checksum does not match the reviewed Buildroot package input' >&2; exit 70; }
buildroot_staging_source="$build_output/host/riscv64-buildroot-linux-gnu/sysroot"
[[ -d "$buildroot_staging_source" ]] || { echo "Audacious core needs the SDK Buildroot staging sysroot: $buildroot_staging_source" >&2; exit 70; }

staged_core_package="$buildroot_tree/package/tdvp-audacious"
config_file="$buildroot_tree/package/Config.in"
config_backup=$(mktemp "$build_output/.config.tdvp-audacious.XXXXXX")
config_old_backup=
package_config_backup=$(mktemp "$buildroot_tree/package/Config.in.tdvp-audacious.XXXXXX")
install_root=$(mktemp -d)
buildroot_staging_root=$(mktemp -d)
buildroot_staging_backup=$(mktemp -d "${buildroot_staging_source}.tdvp-audacious-backup.XXXXXX")
rmdir -- "$buildroot_staging_backup"
download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
base_download_dir=${TDVP_BUILDROOT_BASE_DOWNLOAD_DIR:-}
if [[ -n "$base_download_dir" ]]; then
  [[ -d "$base_download_dir" && ! -L "$base_download_dir" ]] || {
    echo "Audacious core needs a regular baseline Buildroot download directory: $base_download_dir" >&2
    exit 70
  }
  base_download_dir=$(cd -- "$base_download_dir" && pwd)
fi
buildroot_download_dir=${base_download_dir:-$download_dir}
payload_dir="$package_dir/root"
config_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
buildroot_staging_inode=$(stat -c '%d:%i' "$buildroot_staging_source")
config_old_hash=
config_saved=0
config_old_saved=0
package_config_saved=0
core_package_staged=0
staging_source_moved=0
staging_source_redirected=0

cleanup() {
  local rc=$?
  set +e
  if [[ "$package_config_saved" -eq 1 ]]; then cp -- "$package_config_backup" "$config_file"; fi
  if [[ "$config_saved" -eq 1 ]]; then
    # The feed transaction must restore its caller-owned Kconfig inputs
    # byte-for-byte.  Calling olddefconfig here could normalize a completed
    # SDK configuration and turn a successful feed build into a silent config
    # mutation, so restore the saved files directly instead.
    cp --preserve=mode,timestamps -- "$config_backup" "$build_output/.config" || rc=98
    [[ "$(sha256sum "$build_output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
    if [[ "$config_old_saved" -eq 1 ]]; then
      cp --preserve=mode,timestamps -- "$config_old_backup" "$build_output/.config.old" || rc=100
      [[ "$(sha256sum "$build_output/.config.old" | awk '{print $1}')" == "$config_old_hash" ]] || rc=101
    elif [[ -e "$build_output/.config.old" || -L "$build_output/.config.old" ]]; then
      rm -f -- "$build_output/.config.old" || rc=102
    fi
  fi
  if [[ "$core_package_staged" -eq 1 ]]; then rm -rf -- "$staged_core_package"; fi
  if [[ "$staging_source_moved" -eq 1 ]]; then
    if [[ "$staging_source_redirected" -eq 1 ]]; then
      if [[ -L "$buildroot_staging_source" && "$(readlink -f -- "$buildroot_staging_source")" == "$buildroot_staging_root" ]]; then
        rm -f -- "$buildroot_staging_source" || rc=103
      else
        echo 'Audacious core refused to remove an unexpected SDK sysroot path' >&2
        rc=103
      fi
    fi
    if [[ ! -e "$buildroot_staging_source" && ! -L "$buildroot_staging_source" ]]; then
      mv -- "$buildroot_staging_backup" "$buildroot_staging_source" || rc=104
      [[ "$(stat -c '%d:%i' "$buildroot_staging_source")" == "$buildroot_staging_inode" ]] || rc=105
    else
      echo 'Audacious core could not restore the original SDK sysroot path' >&2
      rc=104
    fi
  fi
  rm -f -- "$config_backup" "$config_old_backup" "$package_config_backup"
  # If restoration failed, leave the moved original sysroot backup in place
  # rather than deleting any caller-owned SDK data during error cleanup.
  rm -rf -- "$install_root" "$buildroot_staging_root" "$download_dir"
  exit "$rc"
}
trap cleanup EXIT

[[ ! -e "$staged_core_package" ]] || { echo "refusing to replace existing Buildroot package: $staged_core_package" >&2; exit 71; }
cp -- "$build_output/.config" "$config_backup"; config_saved=1
if [[ -e "$build_output/.config.old" || -L "$build_output/.config.old" ]]; then
  [[ -f "$build_output/.config.old" && ! -L "$build_output/.config.old" ]] || { echo 'Buildroot config backup is not a regular file' >&2; exit 73; }
  config_old_backup=$(mktemp "$build_output/.config.old.tdvp-audacious.XXXXXX")
  cp --preserve=mode,timestamps -- "$build_output/.config.old" "$config_old_backup"
  config_old_hash=$(sha256sum "$build_output/.config.old" | awk '{print $1}')
  config_old_saved=1
fi
cp -- "$config_file" "$package_config_backup"; package_config_saved=1
cp -a -- "$support_core_dir" "$staged_core_package"; core_package_staged=1
printf '\nsource "package/tdvp-audacious/Config.in"\n' >>"$config_file"
# Do not install feed-only headers or .pc files into the caller's SDK sysroot.
# A full copy is used rather than a hard-link farm: Buildroot is allowed to
# replace development paths while installing tdvp-audacious.
cp -a --reflink=auto "$buildroot_staging_source/." "$buildroot_staging_root/"
# The external K230 compiler fixes its sysroot path in its specs, so a Make
# STAGING_DIR override would leave the linker looking at the original SDK.
# Move that exact SDK directory aside and put only the disposable copy at its
# fixed path; cleanup verifies the symlink and restores the original inode.
mv -- "$buildroot_staging_source" "$buildroot_staging_backup"; staging_source_moved=1
ln -s -- "$buildroot_staging_root" "$buildroot_staging_source"; staging_source_redirected=1

"$buildroot_tree/utils/config" --file "$build_output/.config" --enable BR2_PACKAGE_TDVP_AUDACIOUS
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$buildroot_download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y make -C "$build_output" olddefconfig
grep -qx 'BR2_PACKAGE_TDVP_AUDACIOUS=y' "$build_output/.config"
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$buildroot_download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y make -C "$build_output" tdvp-audacious-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" BR2_DL_DIR="$buildroot_download_dir" BR2_PRIMARY_SITE="file://$download_dir" BR2_PRIMARY_SITE_ONLY=y make -C "$build_output" TARGET_DIR="$install_root" tdvp-audacious-install-target

for runtime in 'libaudcore.so.6*' 'libaudtag.so.4*' 'libaudgui.so.7*'; do
  shopt -s nullglob; matches=("$install_root"/usr/lib/$runtime); shopt -u nullglob
  [[ ${#matches[@]} -gt 0 ]] || { echo "Audacious core install omitted $runtime" >&2; exit 72; }
done
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/lib"
for runtime in 'libaudcore.so.6*' 'libaudtag.so.4*' 'libaudgui.so.7*'; do
  for library in "$install_root"/usr/lib/$runtime; do cp -a -- "$library" "$payload_dir/usr/lib/"; done
done
source_version=${VERSION%-*}
install -Dm 0644 "$build_output/build/tdvp-audacious-$source_version/COPYING" "$payload_dir/usr/share/licenses/audacious-core/COPYING"
mkdir -p -- "$TDVP_FEED_STAGING_ROOT/usr"
cp -a -- "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
test -s "$buildroot_staging_root/usr/lib/pkgconfig/audacious.pc"
echo "audacious-core payload ready: $payload_dir"
