#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/support/python3-source-build.sh"
work=$(mktemp -d /tmp/tdvp-python-runtime-policy.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
stdlib="$work/usr/lib/python3.13"
mkdir -p "$stdlib/pydoc_data"
touch "$stdlib/pydoc.py" "$stdlib/pydoc_data/topics.py"
tdvp_python3_assert_runtime_exclusions "$work"
rm "$stdlib/pydoc.py"
if tdvp_python3_assert_runtime_exclusions "$work"; then
  echo 'scientific Python runtime accepted missing pydoc' >&2
  exit 1
fi
touch "$stdlib/pydoc.py" "$stdlib/turtle.py"
if tdvp_python3_assert_runtime_exclusions "$work"; then
  echo 'runtime unexpectedly admitted turtle without its GUI dependencies' >&2
  exit 1
fi
rm "$stdlib/turtle.py"
touch "$work/usr/lib/libpython3.so"
if tdvp_python3_assert_runtime_exclusions "$work"; then
  echo 'runtime unexpectedly admitted the generic Python ABI alias' >&2
  exit 1
fi
rm "$work/usr/lib/libpython3.so"
tdvp_python3_assert_runtime_exclusions "$work"
echo 'scientific Python runtime preservation policy: PASS'
