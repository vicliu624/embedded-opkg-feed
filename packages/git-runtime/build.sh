#!/usr/bin/env bash
# Build Git only from the locked Buildroot recipe, then retain the private
# command helpers and templates in a runtime package.  The public `git`
# frontend is a separate, small leaf package.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64;
}
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_GIT_BUILDROOT_OUTPUT:-}")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'GIT_VERSION = 2.48.1' "$tree/package/git/git.mk" || {
  echo 'locked Buildroot Git source differs from the reviewed r9 recipe' >&2; exit 65;
}
for feature in BR2_PACKAGE_OPENSSL BR2_PACKAGE_LIBCURL BR2_PACKAGE_CA_CERTIFICATES BR2_PACKAGE_OPENSSH_CLIENT; do
  grep -Fqx "$feature=y" "$output/.config" || {
    echo "the locked TDVP target lacks required Git transport feature: $feature" >&2; exit 66;
  }
done
install_root=$(mktemp -d)
cleanup() { rm -rf -- "$install_root"; }
trap cleanup EXIT
tdvp_buildroot_install "$output" "$install_root" --enable BR2_PACKAGE_GIT --target git
[[ -x "$install_root/usr/bin/git" && -d "$install_root/usr/libexec/git-core" && -d "$install_root/usr/share/git-core" ]] || {
  echo 'Git target install omitted its required frontend, helper, or template data' >&2; exit 67;
}
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/libexec" "$payload_dir/usr/share"
cp -a "$install_root/usr/libexec/git-core" "$payload_dir/usr/libexec/git-core"
cp -a "$install_root/usr/share/git-core" "$payload_dir/usr/share/git-core"
mkdir -p -- "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
echo "git-runtime payload ready: $payload_dir"
