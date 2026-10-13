#!/usr/bin/env bash
# Preserve a historical package name as an empty, image-bound runtime reference.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 5 && "$2" == --platform && "$3" == tdvp-k230-r1 && "$4" == --sdk-root ]] || exit 64
package_dir=$1
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
base_root=${TDVP_FEED_BASE_ROOT:?locked image root required}
[[ "$LIBRARY_GLOB" =~ ^lib[A-Za-z0-9_-]+\.so\*$ ]] || exit 65
[[ "${PACKAGE_IMAGE_REFERENCE_ONLY:-0}" == 1 && "$PACKAGE_KIND" == runtime
   && "$PACKAGE_AUTO_RUNTIME_DEPENDS" == 0 && "$PACKAGE_BASE_OVERLAY" == identical ]] || exit 67
case "$PACKAGE:$PACKAGE_DEPENDS:$LIBRARY_GLOB" in
  'libncursesw-6:libncursesw:libncursesw.so*'|\
  'libpcre2-8-0:libpcre2-8:libpcre2-8.so*'|\
  'libpopt-0:libpopt:libpopt.so*'|\
  'libreadline-8:libreadline:libreadline.so*'|\
  'libz-1:libz:libz.so*'|\
  'libresolv-2:tdvp-image-toolchain-external-custom:libresolv.so*'|\
  'libutil-1:tdvp-image-toolchain-external-custom:libutil.so*') ;;
  *) echo "invalid historical runtime reference: $PACKAGE" >&2; exit 67 ;;
esac
mapfile -t libraries < <(compgen -G "$base_root/usr/lib/$LIBRARY_GLOB" | LC_ALL=C sort)
[[ ${#libraries[@]} -gt 0 ]] || { echo "missing image library: $LIBRARY_GLOB" >&2; exit 66; }
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
[[ -z "$(find "$payload" -mindepth 1 -print -quit)" ]] || exit 68
echo "$PACKAGE historical ABI name references the locked image provider"
