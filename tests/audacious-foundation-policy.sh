#!/usr/bin/env bash
# Keep the pre-Audacious Buildroot provider layer explicit and offline.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/prepare-audacious-foundation.sh"

for token in \
  'providers=(libglib2 libgtk3 alsa-lib pulseaudio ffmpeg zlib)' \
  'BR2_PRIMARY_SITE_ONLY=y' \
  'Audacious foundation changed the caller-owned Buildroot configuration' \
  'Audacious foundation omitted provider staging stamp' \
  'tdvp-audacious-foundation.tsv'; do
  grep -Fq -- "$token" "$script" || {
    echo "Audacious foundation policy is missing: $token" >&2
    exit 1
  }
done

if grep -Eq 'providers=\([^)]*tdvp-audacious' "$script"; then
  echo 'Audacious foundation must stop before compiling Audacious itself' >&2
  exit 1
fi

echo 'Audacious foundation policy: PASS'
