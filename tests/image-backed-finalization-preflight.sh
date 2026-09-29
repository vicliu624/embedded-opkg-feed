#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
trap 'rm -rf -- "$work_root"' EXIT
mkdir "$work_root/base" "$work_root/source" "$work_root/existing"
printf 'preserve\n' > "$work_root/existing/sentinel"
set +e
bash "$repo_root/scripts/finalize-image-backed-feed.sh" --platform tdvp-k230-r1 \
  --base-root "$work_root/base" --source "$work_root/source" --output "$work_root/existing"
result=$?
set -e
[[ $result == 65 && $(cat "$work_root/existing/sentinel") == preserve ]]
set +e
env -u TDVP_SDK_ROOT bash "$repo_root/scripts/finalize-image-backed-feed.sh" \
  --platform tdvp-k230-r1 --base-root "$work_root/base" \
  --source "$work_root/source" --output "$work_root/missing-sdk"
result=$?
set -e
[[ $result == 66 && ! -e "$work_root/missing-sdk" ]]
echo 'image-backed finalization preflight: PASS'
