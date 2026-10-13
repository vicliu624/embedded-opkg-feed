#!/usr/bin/env bash
# Exercise publication with a committed signed fixture and an ancillary report.
# This tests byte preservation, not image-plan validity (covered separately).
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
trap 'rm -rf -- "$work_root"' EXIT
mkdir -p "$work_root/repo/site" "$work_root/input"
cp -a "$repo_root/scripts" "$repo_root/platforms" "$repo_root/keys" "$work_root/repo/"
platform_id=tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1
cp -a "$repo_root/site/feed/$platform_id/r2/riscv64/." "$work_root/input/"
printf '{"publication_fixture":true}\n' > "$work_root/input/image-backed-report.json"
bash "$work_root/repo/scripts/stage-site.sh" --platform tdvp-k230-r1 --release r99 "$work_root/input"
cmp "$work_root/input/image-backed-report.json" \
  "$work_root/repo/site/feed/$platform_id/r99/riscv64/image-backed-report.json"
bash "$work_root/repo/scripts/promote-stable-channel.sh" --platform tdvp-k230-r1 --release r99
cmp "$work_root/input/image-backed-report.json" \
  "$work_root/repo/site/feed/$platform_id/stable/riscv64/image-backed-report.json"
echo 'image report publication preservation: PASS'
