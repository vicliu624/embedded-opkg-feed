#!/usr/bin/env bash
# Keep the pre-Audacious Buildroot provider layer explicit and offline.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/prepare-audacious-foundation.sh"

for token in \
  'providers=(libglib2 libgtk3 alsa-lib pulseaudio ffmpeg zlib)' \
  'required_development_files=(' \
  'Audacious foundation is missing SDK development input' \
  'SDK sysroot verified' \
  'tdvp-audacious-foundation.tsv'; do
  grep -Fq -- "$token" "$script" || {
    echo "Audacious foundation policy is missing: $token" >&2
    exit 1
  }
done

if grep -Fq 'make -C "$build_output" "${providers[@]}"' "$script" || \
   grep -Fq 'BR2_PRIMARY_SITE_ONLY=y' "$script"; then
  echo 'Audacious foundation must validate the completed SDK instead of rebuilding providers' >&2
  exit 1
fi

echo 'Audacious foundation policy: PASS'
