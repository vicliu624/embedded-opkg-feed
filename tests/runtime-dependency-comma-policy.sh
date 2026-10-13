#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
for metadata in "$repo_root/packages/"*/package.env; do
  source "$metadata"
  IFS=',' read -r -a records <<< "${PACKAGE_DEPENDS:-}"
  for record in "${records[@]}"; do
    # Remove parenthesized version tests; adjacent package names require a comma.
    names=$(printf '%s' "$record" | sed -E 's/\([^)]*\)//g')
    if [[ "$names" =~ [a-z0-9.+-]+[[:space:]]+[a-z0-9.+-]+ ]]; then
      echo "runtime dependencies must be comma-separated: $metadata: $record" >&2
      exit 1
    fi
  done
done
echo 'runtime dependency comma policy: PASS'
