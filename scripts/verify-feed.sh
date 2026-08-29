#!/usr/bin/env bash
# Verify a feed before release. Signature validation uses the committed public
# key; the private key never enters this repository.
set -Eeuo pipefail
IFS=$'\n\t'

require_signature=0
if [[ "${1:-}" == '--require-signature' ]]; then
  require_signature=1
  shift
fi
if [[ $# -ne 3 || "$1" != '--platform' ]]; then
  echo "usage: $0 [--require-signature] --platform <platform-slug> <feed-directory>" >&2
  exit 64
fi

platform_slug=$2
feed_dir=$(cd -- "$3" && pwd)
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
platform_file="$repo_root/platforms/$platform_slug/platform.env"
[[ -f "$platform_file" ]] || { echo "unknown platform: $platform_slug" >&2; exit 65; }
# shellcheck source=/dev/null
source "$platform_file"

[[ -s "$feed_dir/Packages" && -s "$feed_dir/Packages.gz" ]] || {
  echo "missing Packages or Packages.gz in $feed_dir" >&2; exit 66;
}
cmp <(gzip -dc -- "$feed_dir/Packages.gz") "$feed_dir/Packages"

seen=0
while IFS=$'\t' read -r filename size sha256; do
  seen=1
  [[ "$filename" != */* && "$filename" != *'..'* && "$filename" == *.ipk ]] || {
    echo "unsafe Filename in Packages: $filename" >&2; exit 67;
  }
  ipk="$feed_dir/$filename"
  [[ -f "$ipk" ]] || { echo "index references missing package: $filename" >&2; exit 68; }
  [[ "$(wc -c <"$ipk" | tr -d ' ')" == "$size" ]] || { echo "size mismatch for $filename" >&2; exit 69; }
  [[ "$(sha256sum "$ipk" | awk '{print $1}')" == "$sha256" ]] || { echo "SHA256 mismatch for $filename" >&2; exit 70; }

  control=$(mktemp)
  archive=$(mktemp)
  trap 'rm -f -- "$control" "$archive"' EXIT
  ar p "$ipk" control.tar.gz >"$archive"
  tar -xOzf "$archive" ./control >"$control"
  grep -qx "Architecture: $ARCH" "$control" || { echo "wrong architecture in $filename" >&2; exit 71; }
  grep -Fq "Depends: $ABI_PACKAGE (= $ABI_VERSION)" "$control" || { echo "missing exact ABI dependency in $filename" >&2; exit 72; }
  grep -Eq '^Package: [a-z0-9][a-z0-9+.-]*$' "$control" || { echo "invalid package name in $filename" >&2; exit 73; }
  rm -f -- "$control" "$archive"
  trap - EXIT
done < <(
  awk '
    /^Filename: / { f=$2 }
    /^Size: / { s=$2 }
    /^SHA256sum: / { h=$2 }
    /^$/ { if (f != "" && s != "" && h != "") print f "\t" s "\t" h; f=s=h="" }
    END { if (f != "" && s != "" && h != "") print f "\t" s "\t" h }
  ' "$feed_dir/Packages"
)
[[ "$seen" -eq 1 ]] || { echo 'Packages index is empty' >&2; exit 74; }

if [[ "$require_signature" -eq 1 ]]; then
	 signature="$feed_dir/Packages.asc"
	 compatibility_signature="$feed_dir/Packages.gz.asc"
	 public_key="$repo_root/keys/tdvp-repo-public.asc"
	 [[ -s "$signature" ]] || { echo "missing signature: $signature" >&2; exit 75; }
	 [[ -s "$compatibility_signature" ]] || { echo "missing compatibility signature: $compatibility_signature" >&2; exit 75; }
  [[ -s "$public_key" ]] || { echo "missing committed public key: $public_key" >&2; exit 76; }
  command -v gpg >/dev/null || { echo 'gpg is required to verify the release index' >&2; exit 77; }
  keyring=$(mktemp)
  trap 'rm -f -- "$keyring"' EXIT
  gpg --batch --yes --dearmor --output "$keyring" "$public_key"
  gpgv --keyring "$keyring" "$signature" "$feed_dir/Packages"
	 gpgv --keyring "$keyring" "$compatibility_signature" "$feed_dir/Packages.gz"
  rm -f -- "$keyring"
  trap - EXIT
fi
echo "feed verification passed: $feed_dir"
