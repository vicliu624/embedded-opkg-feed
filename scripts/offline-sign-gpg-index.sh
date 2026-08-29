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
index="$feed_dir/Packages.gz"
signature="$feed_dir/Packages.asc"
compatibility_signature="$feed_dir/Packages.gz.asc"
[[ -s "$index" ]] || { echo "missing index: $index" >&2; exit 65; }
[[ ! -e "$signature" ]] || { echo "refusing to overwrite signature: $signature" >&2; exit 66; }
[[ ! -e "$compatibility_signature" ]] || { echo "refusing to overwrite signature: $compatibility_signature" >&2; exit 66; }
command -v gpg >/dev/null || { echo 'gpg not found on signing host' >&2; exit 67; }

gpg --batch --yes --local-user "$GPG_KEY_FINGERPRINT" --armor --detach-sign \
  --output "$signature" "$index"
cp -- "$signature" "$compatibility_signature"
echo "created detached index signatures: $signature and $compatibility_signature"
