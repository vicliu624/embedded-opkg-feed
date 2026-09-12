#!/usr/bin/env bash
# Reuse a verified immutable IPK payload when a new feed revision only changes
# the dependency graph.  This is deliberately not a binary download shortcut:
# the exact public artifact is SHA-256 pinned, its control metadata is checked,
# and build-ipk.sh generates a new control archive with the new closure.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 1 ]]; then
  echo 'usage: reuse-published-ipk-payload.sh <package-directory>' >&2
  exit 64
fi

package_dir=$(cd -- "$1" && pwd)
[[ -f "$package_dir/package.env" ]] || { echo "missing package.env: $package_dir" >&2; exit 65; }
# shellcheck source=/dev/null
source "$package_dir/package.env"

: "${PACKAGE:?package.env must set PACKAGE}"
: "${VERSION:?package.env must set VERSION}"
: "${PACKAGE_ARCH:?package.env must set PACKAGE_ARCH}"
: "${REUSE_IPK_URL:?package.env must set REUSE_IPK_URL}"
: "${REUSE_IPK_SHA256:?package.env must set REUSE_IPK_SHA256}"
[[ "$REUSE_IPK_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
  echo "REUSE_IPK_SHA256 must be a lowercase SHA-256 digest for $PACKAGE" >&2
  exit 66
}

for tool in ar curl sha256sum tar mktemp rm; do
  command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 67; }
done

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT
source_ipk="$work_root/source.ipk"
curl --fail --location --proto '=https' --tlsv1.2 --retry 3 --output "$source_ipk" "$REUSE_IPK_URL"
[[ "$(sha256sum "$source_ipk" | awk '{print $1}')" == "$REUSE_IPK_SHA256" ]] || {
  echo "immutable source artifact digest mismatch for $PACKAGE" >&2
  exit 68
}

ar p "$source_ipk" control.tar.gz | tar -xzO ./control >"$work_root/control"
grep -qx "Package: $PACKAGE" "$work_root/control" || { echo "reused IPK has wrong Package: $PACKAGE" >&2; exit 69; }
grep -qx "Version: $VERSION" "$work_root/control" || { echo "reused IPK has wrong Version: $VERSION" >&2; exit 70; }
grep -qx "Architecture: $PACKAGE_ARCH" "$work_root/control" || { echo "reused IPK has wrong Architecture: $PACKAGE_ARCH" >&2; exit 71; }

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"
ar p "$source_ipk" data.tar.gz | tar -xzf - -C "$payload_dir"
echo "reused immutable payload for $PACKAGE from $REUSE_IPK_URL"
