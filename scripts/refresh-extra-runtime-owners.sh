#!/usr/bin/env bash
# Refresh only the source-built provider records in a copied private runtime
# catalogue.  The target-derived IPKs and their ownership evidence remain the
# immutable SDK/target-runtime cache; a newly admitted source provider must
# not invalidate or regenerate that completed platform catalogue.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
release=
feed_dir=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --release)
      [[ $# -ge 2 ]] || { echo '--release needs a value' >&2; exit 64; }
      release=$2
      shift 2
      ;;
    --feed-dir)
      [[ $# -ge 2 ]] || { echo '--feed-dir needs a value' >&2; exit 64; }
      feed_dir=$2
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$release" && -n "$feed_dir" ]] || {
  echo 'usage: refresh-extra-runtime-owners.sh --platform <platform> --release <rN> --feed-dir <private-feed-dir>' >&2
  exit 64
}
[[ "$release" =~ ^r[1-9][0-9]*$ ]] || {
  echo "invalid immutable feed release: $release" >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
feed_dir=$(cd -- "$feed_dir" && pwd)
owner_map="$feed_dir/.tdvp-runtime-owners.tsv"
extra_owner_manifest="$repo_root/platforms/$platform_slug/extra-runtime-owners.tsv"

[[ -f "$owner_map" && ! -L "$owner_map" ]] || {
  echo "missing regular private runtime owner map: $owner_map" >&2
  exit 65
}
[[ -f "$extra_owner_manifest" && ! -L "$extra_owner_manifest" ]] || {
  echo "missing regular extra runtime owner manifest: $extra_owner_manifest" >&2
  exit 65
}

valid_soname() {
  [[ "$1" =~ ^[^[:space:]\|]+$ ]]
}

valid_package() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]
}

valid_version() {
  [[ "$1" =~ ^[^[:space:]\|]+$ ]]
}

declare -A owner_package=()
declare -A owner_version=()
while IFS='|' read -r soname package version trailing; do
  soname=${soname%$'\r'}
  [[ -n "$soname" ]] || continue
  [[ -z "${trailing:-}" ]] && valid_soname "$soname" && valid_package "$package" && valid_version "$version" || {
    echo "invalid private runtime owner record: $soname" >&2
    exit 66
  }
  [[ -z "${owner_package[$soname]:-}" ]] || {
    echo "duplicate private runtime owner record: $soname" >&2
    exit 66
  }
  owner_package[$soname]=$package
  owner_version[$soname]=$version
done <"$owner_map"

mapfile -t owner_lines < <(sed 's/\r$//' "$extra_owner_manifest")
added=0
for owner_line in "${owner_lines[@]}"; do
  [[ -n "$owner_line" && "$owner_line" != \#* ]] || continue
  IFS='|' read -r soname package version trailing <<<"$owner_line"
  [[ -z "${trailing:-}" ]] && valid_soname "$soname" && valid_package "$package" && valid_version "$version" || {
    echo "invalid extra runtime owner record: $owner_line" >&2
    exit 67
  }

  package_env="$repo_root/packages/$package/package.env"
  [[ -f "$package_env" && ! -L "$package_env" ]] || {
    echo "extra runtime owner package has no regular recipe: $package" >&2
    exit 67
  }
  mapfile -t package_metadata < <(bash -c '
    set -Eeuo pipefail
    source "$1"
    printf "%s\\n%s\\n%s\\n" "${PACKAGE:-}" "${VERSION:-}" "${PACKAGE_RELEASES:-r1}"
  ' bash "$package_env")
  [[ ${#package_metadata[@]} -eq 3 && "${package_metadata[0]}" == "$package" && \
     "${package_metadata[1]}" == "$version" ]] || {
    echo "extra runtime owner metadata is not attested by recipe: $soname" >&2
    exit 68
  }
  [[ " ${package_metadata[2]} " == *" $release "* ]] || continue

  if [[ -n "${owner_package[$soname]:-}" ]]; then
    [[ "${owner_package[$soname]}" == "$package" && "${owner_version[$soname]}" == "$version" ]] || {
      echo "runtime owner conflict for $soname: ${owner_package[$soname]} ${owner_version[$soname]} versus $package $version" >&2
      exit 69
    }
    continue
  fi
  owner_package[$soname]=$package
  owner_version[$soname]=$version
  added=$((added + 1))
done

temporary_map=$(mktemp "$feed_dir/.tdvp-runtime-owners.XXXXXX")
cleanup() { rm -f -- "$temporary_map"; }
trap cleanup EXIT
for soname in "${!owner_package[@]}"; do
  printf '%s|%s|%s\n' "$soname" "${owner_package[$soname]}" "${owner_version[$soname]}"
done | LC_ALL=C sort -u >"$temporary_map"
install -m 0644 "$temporary_map" "$owner_map"
printf 'refreshed %d source-built runtime owner records for %s\n' "$added" "$release"
