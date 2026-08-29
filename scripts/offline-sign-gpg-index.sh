#!/usr/bin/env bash
# Run this only on the release signing host. The private key is deliberately
# external to this repository and to normal GitHub Actions jobs.
set -Eeuo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: GPG_KEY_FINGERPRINT=<fingerprint> $0 <feed-directory>" >&2
  exit 64
fi
: "${GPG_KEY_FINGERPRINT:?set the dedicated release key fingerprint}"

gpg_bin=${TDVP_GPG_BIN:-gpg}
gpg_homedir=${TDVP_GPG_HOMEDIR:-}
gpg_windows_paths=${TDVP_GPG_WINDOWS_PATHS:-0}
gpg_args=()
if [[ -n $gpg_homedir ]]; then
  gpg_args+=(--homedir "$gpg_homedir")
fi

run_gpg() {
  local argument
  local converted_args=()
  for argument in "$@"; do
    if [[ $gpg_windows_paths == 1 && $argument =~ ^/mnt/([[:alpha:]])/(.*)$ ]]; then
      converted_args+=("${BASH_REMATCH[1]^^}:/${BASH_REMATCH[2]}")
    else
      converted_args+=("$argument")
    fi
  done
  "$gpg_bin" "${gpg_args[@]}" "${converted_args[@]}"
}

if [[ $gpg_bin == */* ]]; then
  [[ -x $gpg_bin ]] || { echo "GnuPG executable is not runnable: $gpg_bin" >&2; exit 67; }
else
  command -v "$gpg_bin" >/dev/null || { echo "GnuPG executable not found: $gpg_bin" >&2; exit 67; }
fi

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
run_gpg --batch --yes --local-user "$GPG_KEY_FINGERPRINT" --armor --detach-sign \
  --output "$signature" "$index"
if [[ ! -e "$compatibility_signature" ]]; then
  run_gpg --batch --yes --local-user "$GPG_KEY_FINGERPRINT" --armor --detach-sign \
    --output "$compatibility_signature" "$compressed_index"
fi
echo "created detached primary signature: $signature (Packages)"
