#!/usr/bin/env bash
# Exercise the version boundary used when a verified historical payload is
# reissued with a newer control archive.  This is local-only: curl is replaced
# with a fixture copier, while ar/tar still parse a genuine tiny IPK.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_root=$(mktemp -d)
cleanup() { rm -rf -- "$fixture_root"; }
trap cleanup EXIT

package_dir="$fixture_root/package"
payload_root="$fixture_root/payload"
tool_dir="$fixture_root/tools"
mkdir -p "$package_dir" "$payload_root/usr/bin" "$tool_dir" "$fixture_root/ar"
printf 'fixture payload\n' >"$payload_root/usr/bin/fixture"
chmod 0755 "$payload_root/usr/bin/fixture"

printf '2.0\n' >"$fixture_root/ar/debian-binary"
printf '%s\n' \
  'Package: fixture-payload' \
  'Version: 1.0-1' \
  'Architecture: riscv64' \
  >"$fixture_root/ar/control"
tar -C "$fixture_root/ar" -czf "$fixture_root/ar/control.tar.gz" ./control
tar -C "$payload_root" -czf "$fixture_root/ar/data.tar.gz" .
ar r "$fixture_root/source.ipk" \
  "$fixture_root/ar/debian-binary" \
  "$fixture_root/ar/control.tar.gz" \
  "$fixture_root/ar/data.tar.gz" >/dev/null
source_digest=$(sha256sum "$fixture_root/source.ipk" | awk '{print $1}')

printf "%s\n" \
  "PACKAGE='fixture-payload'" \
  "VERSION='2.0-1'" \
  "PACKAGE_ARCH='riscv64'" \
  "REUSE_IPK_URL='https://fixture.invalid/fixture-payload_1.0-1_riscv64.ipk'" \
  "REUSE_IPK_SHA256='$source_digest'" \
  >"$package_dir/package.env"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -Eeuo pipefail' \
  "output=''" \
  'while [[ $# -gt 0 ]]; do' \
  '  case "$1" in' \
  '    --output) output=$2; shift 2 ;;' \
  '    *) shift ;;' \
  '  esac' \
  'done' \
  'test -n "$output"' \
  'cp -- "$FIXTURE_IPK" "$output"' \
  >"$tool_dir/curl"
chmod 0755 "$tool_dir/curl"

expect_status() {
  local expected=$1
  shift
  set +e
  "$@" >"$fixture_root/command.log" 2>&1
  local actual=$?
  set -e
  [[ "$actual" -eq "$expected" ]] || {
    echo "expected exit $expected, got $actual" >&2
    sed -n '1,160p' "$fixture_root/command.log" >&2
    exit 1
  }
}

# Without the explicit source-version declaration, the historical strict
# policy still rejects a source IPK whose control revision differs.
expect_status 70 env PATH="$tool_dir:$PATH" FIXTURE_IPK="$fixture_root/source.ipk" \
  bash "$repo_root/scripts/reuse-published-ipk-payload.sh" "$package_dir"

printf "REUSE_IPK_VERSION='1.0-1'\n" >>"$package_dir/package.env"
env PATH="$tool_dir:$PATH" FIXTURE_IPK="$fixture_root/source.ipk" \
  bash "$repo_root/scripts/reuse-published-ipk-payload.sh" "$package_dir" >/dev/null
test -x "$package_dir/root/usr/bin/fixture"
cmp -s "$payload_root/usr/bin/fixture" "$package_dir/root/usr/bin/fixture"

sed -i "s/REUSE_IPK_VERSION='1.0-1'/REUSE_IPK_VERSION='0.9-1'/" "$package_dir/package.env"
expect_status 70 env PATH="$tool_dir:$PATH" FIXTURE_IPK="$fixture_root/source.ipk" \
  bash "$repo_root/scripts/reuse-published-ipk-payload.sh" "$package_dir"

echo 'reuse published IPK payload policy: PASS'
