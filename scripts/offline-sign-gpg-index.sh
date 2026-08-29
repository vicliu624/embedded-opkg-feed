#!/usr/bin/env bash
# Run this only on the release signing host. The private key is deliberately
# external to this repository and to normal GitHub Actions jobs.
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: GPG_KEY_FINGERPRINT=<fingerprint> $0 <feed-directory>" >&2
  exit 64
fi
: "${GPG_KEY_FINGERPRINT:?set the dedicated release key fingerprint}"

feed_dir=$(cd -- "$1" && pwd)
index="$feed_dir/Packages"
compressed_index="$feed_dir/Packages.gz"
signature="$feed_dir/Packages.asc"
compatibility_signature="$feed_dir/Packages.gz.asc"
[[ -s "$index" ]] || { echo "missing index: $index" >&2; exit 65; }
[[ -s "$compressed_index" ]] || { echo "missing compressed index: $compressed_index" >&2; exit 65; }
if [[ -e "$signature" ]]; then
  [[ ${TDVP_REPLACE_OPKG_PRIMARY_SIGNATURE:-0} == 1 ]] || {
    echo "refusing to overwrite signature: $signature" >&2; exit 66;
  }
  rm -f -- "$signature"
fi
command -v gpg >/dev/null || { echo 'gpg not found on signing host' >&2; exit 67; }

gpg --batch --yes --local-user "$GPG_KEY_FINGERPRINT" --armor --detach-sign \
  --output "$signature" "$index"
if [[ ! -e "$compatibility_signature" ]]; then
  gpg --batch --yes --local-user "$GPG_KEY_FINGERPRINT" --armor --detach-sign \
    --output "$compatibility_signature" "$compressed_index"
fi
echo "created detached primary signature: $signature (Packages)"
