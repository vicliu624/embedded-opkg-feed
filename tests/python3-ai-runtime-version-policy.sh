#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
for name in numpy scipy pillow opencv tdvp-ai; do
  source "$repo_root/packages/python3-$name/package.env"
  [[ "$PACKAGE_DEPENDS" == 'python3 (>= 3.13.3-2), '* ]] || {
    echo "python3-$name must upgrade the complete Python runtime" >&2
    exit 1
  }
done
source "$repo_root/packages/python3/package.env"
[[ "$VERSION" == 3.13.3-3 && "$PACKAGE_DEPENDS" == 'python3-runtime (= 3.13.3-3)' ]]
source "$repo_root/packages/python3-runtime/package.env"
[[ "$VERSION" == 3.13.3-3 ]]
echo 'scientific Python minimum runtime version policy: PASS'
