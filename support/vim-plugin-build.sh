#!/usr/bin/env bash
# Build a pure Vim runtime plugin from an immutable upstream source archive.
# It intentionally accepts only Vimscript/text payload directories; native
# helpers must get their own riscv64 cross-build recipe and runtime ownership.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <vim-plugin-package-directory>" >&2
  exit 64
fi

package_dir=$(cd -- "$1" && pwd)
source "$package_dir/package.env"

: "${VIM_PLUGIN_DIRECTORY:?package.env must set VIM_PLUGIN_DIRECTORY}"
: "${VIM_PLUGIN_REQUIRED_FILE:?package.env must set VIM_PLUGIN_REQUIRED_FILE}"
: "${SOURCE_ARCHIVE:?package.env must set SOURCE_ARCHIVE}"
: "${SOURCE_ARCHIVE_SHA256:?package.env must set SOURCE_ARCHIVE_SHA256}"
: "${SOURCE_ARCHIVE_URL:?package.env must set SOURCE_ARCHIVE_URL}"
[[ "$VIM_PLUGIN_DIRECTORY" =~ ^[a-z0-9][a-z0-9._+-]*$ ]] || { echo "invalid Vim plugin directory: $VIM_PLUGIN_DIRECTORY" >&2; exit 65; }
[[ "$VIM_PLUGIN_REQUIRED_FILE" != /* && "$VIM_PLUGIN_REQUIRED_FILE" != *'..'* ]] || { echo "unsafe Vim plugin required path: $VIM_PLUGIN_REQUIRED_FILE" >&2; exit 66; }

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT
archive="$work_root/$SOURCE_ARCHIVE"
source_root="$work_root/source"
payload_dir="$package_dir/root"

curl --fail --location --retry 3 --output "$archive" "$SOURCE_ARCHIVE_URL"
actual_sha256=$(sha256sum "$archive" | awk '{print $1}')
[[ "$actual_sha256" == "$SOURCE_ARCHIVE_SHA256" ]] || {
  echo "$PACKAGE source hash mismatch: expected $SOURCE_ARCHIVE_SHA256, got $actual_sha256" >&2
  exit 67
}
mkdir -p -- "$source_root"
tar -xzf "$archive" -C "$source_root" --strip-components=1
[[ -f "$source_root/$VIM_PLUGIN_REQUIRED_FILE" ]] || { echo "$PACKAGE source does not contain $VIM_PLUGIN_REQUIRED_FILE" >&2; exit 68; }

rm -rf -- "$payload_dir"
plugin_root="$payload_dir/usr/share/vim/vim91/pack/tdvp/start/$VIM_PLUGIN_DIRECTORY"
mkdir -p -- "$plugin_root" "$payload_dir/usr/share/doc/$PACKAGE"
for directory in autoload plugin; do
  [[ -d "$source_root/$directory" ]] || continue
  cp -a -- "$source_root/$directory" "$plugin_root/$directory"
done
cp -a -- "$source_root/README.markdown" "$payload_dir/usr/share/doc/$PACKAGE/README.markdown" 2>/dev/null || true

# The installed tree is intentionally a text-only Vim package.  A native
# binary, .so, or a plugin-owned executable would need an explicit riscv64
# build and cannot bypass the feed runtime-closure audit here.
if find "$plugin_root" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -u+x \) -print -quit | grep -q .; then
  echo "$PACKAGE is not a pure Vimscript plugin; create a dedicated riscv64 recipe instead" >&2
  exit 69
fi
[[ -f "$plugin_root/$VIM_PLUGIN_REQUIRED_FILE" ]] || { echo "$PACKAGE payload lost $VIM_PLUGIN_REQUIRED_FILE" >&2; exit 70; }
echo "$PACKAGE payload ready: $payload_dir"
