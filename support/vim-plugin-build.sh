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
: "${TDVP_SOURCE_CACHE_ROOT:?Vim plugin builds require TDVP_SOURCE_CACHE_ROOT from scripts/build-all.sh}"
source_cache_root=$(cd -- "$TDVP_SOURCE_CACHE_ROOT" && pwd)
archive="$source_cache_root/sha256/$SOURCE_ARCHIVE_SHA256/$SOURCE_ARCHIVE"
[[ -f "$archive" && ! -L "$archive" ]] || {
  echo "$PACKAGE source cache is missing $SOURCE_ARCHIVE; build through scripts/build-all.sh" >&2
  exit 67
}
source_root="$work_root/source"
payload_dir="$package_dir/root"

actual_sha256=$(sha256sum "$archive" | awk '{print $1}')
[[ "$actual_sha256" == "$SOURCE_ARCHIVE_SHA256" ]] || {
  echo "$PACKAGE source hash mismatch: expected $SOURCE_ARCHIVE_SHA256, got $actual_sha256" >&2
  exit 68
}
mkdir -p -- "$source_root"
tar -xzf "$archive" -C "$source_root" --strip-components=1
[[ -f "$source_root/$VIM_PLUGIN_REQUIRED_FILE" ]] || { echo "$PACKAGE source does not contain $VIM_PLUGIN_REQUIRED_FILE" >&2; exit 69; }

rm -rf -- "$payload_dir"
plugin_root="$payload_dir/usr/share/vim/vim91/pack/tdvp/start/$VIM_PLUGIN_DIRECTORY"
mkdir -p -- "$plugin_root" "$payload_dir/usr/share/doc/$PACKAGE"
for directory in autoload plugin; do
  [[ -d "$source_root/$directory" ]] || continue
  cp -a -- "$source_root/$directory" "$plugin_root/$directory"
done
for document in README.markdown README.md; do
  [[ -f "$source_root/$document" ]] || continue
  install -Dm 0644 "$source_root/$document" "$payload_dir/usr/share/doc/$PACKAGE/$document"
done
for licence in LICENSE LICENCE; do
  [[ -f "$source_root/$licence" ]] || continue
  install -Dm 0644 "$source_root/$licence" "$payload_dir/usr/share/licenses/$PACKAGE/$licence"
done

# The installed tree is intentionally a text-only Vim package.  Check the
# payload's actual content and allowed filenames, rather than execute bits:
# a Windows worktree mounted into WSL can report every ordinary text file as
# executable even when its committed Git mode is 0644.  A native binary, .so,
# symlink, shebang script, or non-Vim payload still needs a dedicated riscv64
# recipe and cannot bypass the runtime-closure audit here.
if find "$plugin_root" -type l -print -quit | grep -q . || \
   find "$plugin_root" -type f ! -name '*.vim' -print -quit | grep -q .; then
  echo "$PACKAGE is not a pure Vimscript plugin; create a dedicated riscv64 recipe instead" >&2
  exit 70
fi
while IFS= read -r -d '' vim_file; do
  if [[ -s "$vim_file" ]] && ! LC_ALL=C grep -Iq . "$vim_file"; then
    echo "$PACKAGE contains a non-text Vim payload: $vim_file" >&2
    exit 71
  fi
  if LC_ALL=C grep -q '^#!' "$vim_file"; then
    echo "$PACKAGE contains a script shebang: $vim_file" >&2
    exit 72
  fi
done < <(find "$plugin_root" -type f -name '*.vim' -print0)
[[ -f "$plugin_root/$VIM_PLUGIN_REQUIRED_FILE" ]] || { echo "$PACKAGE payload lost $VIM_PLUGIN_REQUIRED_FILE" >&2; exit 71; }
echo "$PACKAGE payload ready: $payload_dir"
