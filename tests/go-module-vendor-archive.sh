#!/usr/bin/env bash
# Verify that the Go archive builder canonicalizes file permissions.  The
# production invocation supplies the reviewed locked Go binary; this unit test
# only exercises the standard-library program's format invariants.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-go-vendor-archive.XXXXXX")
cleanup() {
  local rc=$?
  rm -rf -- "$work_root"
  exit "$rc"
}
trap cleanup EXIT

go_binary=${TDVP_GO_MODULE_VENDOR_TEST_GO_BINARY:-$(command -v go || true)}
if [[ -z "$go_binary" ]]; then
  echo 'go-module-vendor archive policy: SKIP (no host Go compiler)'
  exit 0
fi
mkdir -p -- "$work_root/a/vendor/example" "$work_root/b/vendor/example"
printf 'same content\n' >"$work_root/a/vendor/example/module.go"
cp -- "$work_root/a/vendor/example/module.go" "$work_root/b/vendor/example/module.go"
printf '# modules\n' >"$work_root/a/vendor/modules.txt"
cp -- "$work_root/a/vendor/modules.txt" "$work_root/b/vendor/modules.txt"
chmod -R 0755 -- "$work_root/a/vendor"
chmod -R 0775 -- "$work_root/b/vendor"
chmod 0644 "$work_root/a/vendor/example/module.go" "$work_root/a/vendor/modules.txt"
chmod 0664 "$work_root/b/vendor/example/module.go" "$work_root/b/vendor/modules.txt"

"$go_binary" run "$repo_root/support/go-module-vendor-archive.go" "$work_root/a/vendor" "$work_root/a.tar.gz"
"$go_binary" run "$repo_root/support/go-module-vendor-archive.go" "$work_root/b/vendor" "$work_root/b.tar.gz"
cmp -- "$work_root/a.tar.gz" "$work_root/b.tar.gz"
tar -tzf "$work_root/a.tar.gz" | cmp - <(printf 'vendor/\nvendor/example/\nvendor/example/module.go\nvendor/modules.txt\n')
echo 'go-module-vendor archive policy: PASS'
