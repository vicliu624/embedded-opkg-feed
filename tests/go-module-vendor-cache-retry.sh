#!/usr/bin/env bash
# Exercise the retry boundary with a Go command that first returns a partial
# module resolution successfully, then produces the locked vendor tree.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-go-vendor-retry.XXXXXX")
cleanup() {
  local rc=$?
  chmod -R u+w -- "$work_root" 2>/dev/null || true
  rm -rf -- "$work_root"
  exit "$rc"
}
trap cleanup EXIT

package_dir="$work_root/packages/fixture"
source_root="$work_root/source"
cache_root="$work_root/cache"
mkdir -p -- "$package_dir" "$source_root" "$cache_root"
printf 'module example.invalid/fixture\n\ngo 1.20\n' >"$source_root/go.mod"
: >"$source_root/go.sum"

# Derive the immutable fixture lock from the exact output a successful retry
# must produce.  The first fake Go pass instead appends a different sum line.
printf '# example.invalid/module v1.0.0\n## explicit; go 1.20\n' >"$source_root/vendor.modules"
mkdir -p -- "$source_root/vendor"
mv -- "$source_root/vendor.modules" "$source_root/vendor/modules.txt"
resolved_sum='example.invalid/module v1.0.0 h1:locked\n'
printf '%b' "$resolved_sum" >"$source_root/go.sum"
vendor_modules_sha=$(sha256sum "$source_root/vendor/modules.txt" | awk '{print $1}')
(
  cd -- "$source_root"
  tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner --format=gnu \
    --mode='u+rw,go+r,go-w' \
    -cf - vendor | gzip -n >"$work_root/expected-vendor.tar.gz"
)
vendor_archive_sha=$(sha256sum "$work_root/expected-vendor.tar.gz" | awk '{print $1}')
resolved_sum_sha=$(sha256sum "$source_root/go.sum" | awk '{print $1}')
rm -rf -- "$source_root/vendor"
: >"$source_root/go.sum"
source_sum_sha=$(sha256sum "$source_root/go.sum" | awk '{print $1}')
go_mod_sha=$(sha256sum "$source_root/go.mod" | awk '{print $1}')

cat >"$package_dir/go-modules.lock" <<EOF
FORMAT_VERSION='1'
GO_TOOLCHAIN_VERSION='1.26.7'
GO_TOOLCHAIN_HOST_OS='linux'
GO_TOOLCHAIN_HOST_ARCH='amd64'
GO_TOOLCHAIN_ARCHIVE='go1.26.7.linux-amd64.tar.gz'
GO_TOOLCHAIN_ARCHIVE_SHA256='0000000000000000000000000000000000000000000000000000000000000000'
GO_MOD_SHA256='$go_mod_sha'
GO_SUM_SHA256='$source_sum_sha'
GO_RESOLVED_SUM_SHA256='$resolved_sum_sha'
GO_VENDOR_MODULES_SHA256='$vendor_modules_sha'
GO_VENDOR_MODULE_COUNT='1'
GO_MODULE_VENDOR_ARCHIVE='fixture-vendor.tar.gz'
GO_MODULE_VENDOR_ARCHIVE_SHA256='$vendor_archive_sha'
EOF

fake_go="$work_root/fake-go"
cat >"$fake_go" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
if [[ "$1" == run ]]; then
  source_root=$3
  output=$4
  (
    cd -- "$(dirname -- "$source_root")"
    tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner --format=gnu \
      --mode='u+rw,go+r,go-w' \
      -cf - "$(basename -- "$source_root")" | gzip -n >"$output"
  )
  exit 0
fi
case "$1 $2 ${3:-}" in
  'mod download all')
    count=$(cat "$TDVP_TEST_GO_ATTEMPTS")
    count=$((count + 1))
    printf '%s\n' "$count" >"$TDVP_TEST_GO_ATTEMPTS"
    ;;
  'mod verify ')
    printf 'all modules verified\n'
    ;;
  'mod vendor ')
    count=$(cat "$TDVP_TEST_GO_ATTEMPTS")
    if [[ "$count" == 1 ]]; then
      printf 'example.invalid/module v1.0.0 h1:partial\n' >>go.sum
    else
      printf 'example.invalid/module v1.0.0 h1:locked\n' >>go.sum
    fi
    mkdir -p vendor
    printf '# example.invalid/module v1.0.0\n## explicit; go 1.20\n' >vendor/modules.txt
    # The source content is locked, but a module cache copied under another
    # umask can retain a different mode. The helper must canonicalize it
    # before hashing its vendor archive.
    chmod 0660 vendor/modules.txt
    ;;
  *)
    echo "unexpected fake go invocation: $*" >&2
    exit 64
    ;;
esac
EOF
chmod 0755 "$fake_go"
attempt_file="$work_root/attempts"
printf '0\n' >"$attempt_file"

export TDVP_SOURCE_CACHE_ROOT="$cache_root"
export TDVP_TEST_GO_ATTEMPTS="$attempt_file"
export TDVP_GO_MODULE_VENDOR_RETRY_ATTEMPTS=2
export TDVP_GO_MODULE_VENDOR_RETRY_DELAY_SECONDS=0
# shellcheck source=../support/go-module-vendor-cache.sh
source "$repo_root/support/go-module-vendor-cache.sh"
tdvp_load_go_module_vendor_lock "$package_dir"
cache_file=$(tdvp_prepare_go_module_vendor_cache "$source_root" "$fake_go" "$work_root")

[[ "$(cat "$attempt_file")" == 2 ]]
[[ -f "$cache_file" && ! -L "$cache_file" ]]
[[ "$(sha256sum "$cache_file" | awk '{print $1}')" == "$vendor_archive_sha" ]]
[[ "$(sha256sum "$source_root/go.sum" | awk '{print $1}')" == "$resolved_sum_sha" ]]
echo 'go-module-vendor-cache retry policy: PASS'
