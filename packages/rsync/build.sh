#!/usr/bin/env bash
# Build a compact rsync command from the reviewed Buildroot recipe. Remote
# transport is supplied by the separately owned OpenSSH client; optional ACL,
# LZ4, OpenSSL daemon TLS, xxHash, and Zstd features stay out of r10.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_DEVEL_BUILDROOT_OUTPUT || true)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
grep -Fqx 'BR2_PACKAGE_ZLIB=y' "$output/.config" || {
  echo 'matching Buildroot output lacks required rsync SDK feature: BR2_PACKAGE_ZLIB=y' >&2
  exit 65
}
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
local_patch="$package_dir/patches/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"
tree_patch="$tree/package/rsync/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"
[[ -f "$local_patch" && ! -L "$local_patch" && -f "$tree_patch" && ! -L "$tree_patch" ]] || {
  echo 'reviewed rsync Buildroot patch is missing' >&2
  exit 66
}
normalised_patch_sha256() {
  sed 's/\r$//' "$1" | awk '
    { lines[NR] = $0; if ($0 != "") last = NR }
    END { for (line_index = 1; line_index <= last; line_index++) print lines[line_index] }
  ' | sha256sum | awk '{print $1}'
}
local_patch_hash=$(normalised_patch_sha256 "$local_patch") || {
  echo 'could not normalize the locked rsync patch' >&2
  exit 67
}
tree_patch_hash=$(normalised_patch_sha256 "$tree_patch") || {
  echo 'could not normalize the matching Buildroot rsync patch' >&2
  exit 67
}
[[ "$local_patch_hash" == "$tree_patch_hash" ]] || {
  echo 'locked rsync patch differs from the matching Buildroot tree' >&2
  exit 67
}

# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_ACL BR2_PACKAGE_LZ4 BR2_PACKAGE_OPENSSL BR2_PACKAGE_XXHASH BR2_PACKAGE_ZSTD' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "$configured_output" \
    BR2_PACKAGE_RSYNC rsync 'RSYNC_VERSION = 3.4.1' 'rsync'
