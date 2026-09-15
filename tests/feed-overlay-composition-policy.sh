#!/usr/bin/env bash
# Prove an incremental overlay adds or replaces selected packages without
# silently dropping unrelated payloads from the signed immutable foundation.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
platform_id='tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1'
base_feed="$repo_root/site/feed/$platform_id/r2/riscv64"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
overlay="$work_dir/overlay"
output="$work_dir/composed"
fixture_recipe="$work_dir/tdvp-overlay-composition-test"

[[ -s "$base_feed/Packages" && -s "$base_feed/Packages.asc" ]] || {
  echo "missing signed r2 fixture: $base_feed" >&2
  exit 65
}
mkdir -p "$overlay"
cp -a "$repo_root/packages/tdvp-hello" "$fixture_recipe"
sed -i "s/^PACKAGE='tdvp-hello'$/PACKAGE='tdvp-overlay-composition-test'/" "$fixture_recipe/package.env"
bash "$repo_root/scripts/build-ipk.sh" --platform tdvp-k230-r1 \
  "$fixture_recipe" "$overlay"
bash "$repo_root/scripts/make-index.sh" "$overlay"
bash "$repo_root/scripts/verify-feed.sh" --platform tdvp-k230-r1 "$overlay"
grep -q '^Package: tdvp-overlay-composition-test$' "$overlay/Packages"
if grep -q '^Package: tdvp-overlay-composition-test$' "$base_feed/Packages"; then
  echo 'r2 fixture unexpectedly already contains the overlay test package' >&2
  exit 66
fi

bash "$repo_root/scripts/compose-signed-feed-overlay.sh" \
  --platform tdvp-k230-r1 --base "$base_feed" --overlay "$overlay" --output "$output"

base_count=$(grep -c '^Package: ' "$base_feed/Packages")
output_count=$(grep -c '^Package: ' "$output/Packages")
[[ "$output_count" -eq $((base_count + 1)) ]] || {
  echo "composition package count mismatch: base=$base_count output=$output_count" >&2
  exit 67
}
grep -q '^Package: tdvp-overlay-composition-test$' "$output/Packages"
while IFS= read -r base_package; do
  grep -Fqx "Package: $base_package" "$output/Packages" || {
    echo "composition dropped signed base package: $base_package" >&2
    exit 68
  }
done < <(sed -n 's/^Package: //p' "$base_feed/Packages")
bash "$repo_root/scripts/verify-feed.sh" --platform tdvp-k230-r1 "$output"
echo 'feed-overlay-composition-policy: PASS'
