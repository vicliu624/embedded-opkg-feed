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
sdk_root=$4
source "$package_dir/package.env"

[[ -d "$sdk_root" && -d "$support_dir" ]] || { echo 'audacious-core needs the matching Buildroot SDK and support files' >&2; exit 66; }
sdk_root=$(cd -- "$sdk_root" && pwd)
build_output=${TDVP_AUDACIOUS_BUILDROOT_OUTPUT:-$(cd -- "$sdk_root/.." && pwd)}
[[ "$sdk_root" == "$build_output/host" && -f "$build_output/.config" && -f "$build_output/Makefile" && -d "$build_output/target" ]] || { echo 'TDVP_AUDACIOUS_BUILDROOT_OUTPUT must be a completed matching Buildroot output' >&2; exit 67; }
buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree" && -x "$buildroot_tree/utils/config" ]] || { echo 'could not resolve the locked Buildroot tree from the SDK output' >&2; exit 68; }
actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == '2025.02.1' ]] || { echo "expected Buildroot 2025.02.1, got ${actual_buildroot_version:-unknown}" >&2; exit 69; }
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$support_dir/tdvp-audacious.hash" || { echo 'Audacious source checksum does not match the reviewed Buildroot package input' >&2; exit 70; }

staged_package="$buildroot_tree/package/tdvp-audacious"
config_file="$buildroot_tree/package/Config.in"
config_backup=$(mktemp "$build_output/.config.tdvp-audacious.XXXXXX")
package_config_backup=$(mktemp "$buildroot_tree/package/Config.in.tdvp-audacious.XXXXXX")
install_root=$(mktemp -d)
payload_dir="$package_dir/root"
config_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
config_saved=0
package_config_saved=0
package_staged=0

cleanup() {
  local rc=$?
  set +e
  if [[ "$package_config_saved" -eq 1 ]]; then cp -- "$package_config_backup" "$config_file"; fi
  if [[ "$config_saved" -eq 1 ]]; then
    cp -- "$config_backup" "$build_output/.config"
    # .config alone is not enough: olddefconfig regenerates Buildroot's
    # derived configuration too, so this temporary external package cannot
    # leak into the next firmware build using the same output directory.
    env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" olddefconfig || rc=98
    [[ "$(sha256sum "$build_output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
  fi
  if [[ "$package_staged" -eq 1 ]]; then rm -rf -- "$staged_package"; fi
  rm -f -- "$config_backup" "$package_config_backup"
  rm -rf -- "$install_root"
  exit "$rc"
}
trap cleanup EXIT

[[ ! -e "$staged_package" ]] || { echo "refusing to replace existing Buildroot package: $staged_package" >&2; exit 71; }
cp -- "$build_output/.config" "$config_backup"; config_saved=1
cp -- "$config_file" "$package_config_backup"; package_config_saved=1
cp -a -- "$support_dir" "$staged_package"; package_staged=1
printf '\nsource "package/tdvp-audacious/Config.in"\n' >>"$config_file"

"$buildroot_tree/utils/config" --file "$build_output/.config" --enable BR2_PACKAGE_TDVP_AUDACIOUS
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" olddefconfig
grep -qx 'BR2_PACKAGE_TDVP_AUDACIOUS=y' "$build_output/.config"
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" tdvp-audacious-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" TARGET_DIR="$install_root" tdvp-audacious-install-target

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
echo "audacious-core payload ready: $payload_dir"
