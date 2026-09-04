#!/usr/bin/env bash
# Exercise the narrow same-transaction command-staging extension without a
# firmware SDK. This fixture verifies option forwarding, staging provenance,
# collision refusal, and Buildroot config restoration; real candidate CI still
# performs the target-ELF/IPK closure checks with the matching K230 toolchain.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../support/buildroot-archive-library.sh
source "$repo_root/support/buildroot-archive-library.sh"

work_root=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/libcurl-4"
leaf_dir="$fixture_repo/packages/curl"
tree="$work_root/buildroot"
output="$work_root/output"
stage_root="$work_root/staging"
mkdir -p -- \
  "$package_dir" \
  "$leaf_dir" \
  "$fixture_repo/support" \
  "$tree/utils" \
  "$tree/package/libcurl" \
  "$output/host/bin" \
  "$output/target" \
  "$stage_root"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/source-archive-library.sh" "$fixture_repo/support/"
cp -- "$repo_root/packages/curl/build.sh" "$leaf_dir/build.sh"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/package/libcurl/libcurl.mk" <<'EOF'
LIBCURL_VERSION = 8.12.1
EOF
cat >"$tree/utils/config" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
config_file=
mode=
symbol=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) config_file=$2; shift 2 ;;
    --enable|--disable) mode=${1#--}; symbol=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s:%s\n' "$mode" "$symbol" >>"$(dirname -- "$config_file")/.tdvp-enable.log"
case "$mode" in
  enable) printf '%s=y\n' "$symbol" >>"$config_file" ;;
  disable) sed -i "/^${symbol}=y$/d" "$config_file" ;;
  *) exit 2 ;;
esac
EOF
chmod 0755 "$tree/utils/config"

cat >"$output/Makefile" <<EOF
MAKEARGS := -C $tree
EOF
cat >"$output/host/bin/make" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=
target_root=
previous=
for argument in "$@"; do
  if [[ "$previous" == '-C' ]]; then
    output=$argument
    previous=
    continue
  fi
  case "$argument" in
    TARGET_DIR=*) target_root=${argument#TARGET_DIR=} ;;
  esac
  previous=$argument
done
[[ -n "$output" ]] || exit 2
case " $* " in
  *' olddefconfig '*) exit 0 ;;
  *' libcurl-dirclean '*) exit 0 ;;
  *' libcurl-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/lib" "$target_root/usr/bin"
    printf 'fixture libcurl\n' >"$target_root/usr/lib/libcurl.so.4"
    printf 'fixture curl command\n' >"$target_root/usr/bin/curl"
    chmod 0755 -- "$target_root/usr/bin/curl"
    exit 0
    ;;
esac
exit 4
EOF
chmod 0755 "$output/host/bin/make"
cat >"$output/host/bin/riscv64-unknown-linux-gnu-readelf" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in
  -h) printf '%s\n' '  Machine:                           RISC-V' ;;
  -d|-dW) printf '%s\n' ' 0x0000000000000001 (NEEDED)             Shared library: [libcurl.so.4]' ;;
  *) exit 2 ;;
esac
EOF
chmod 0755 "$output/host/bin/riscv64-unknown-linux-gnu-readelf"
printf 'ORIGINAL_CONFIG=y\n' >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

TDVP_FEED_STAGING_ROOT="$stage_root" \
  tdvp_build_archive_library "$package_dir" "$output/host" '' \
  BR2_PACKAGE_LIBCURL libcurl 'libcurl.so*' 'LIBCURL_VERSION = 8.12.1' \
  --enable BR2_PACKAGE_LIBCURL_CURL --disable BR2_PACKAGE_LIBICONV \
  --stage-command /usr/bin/curl

[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
grep -Fqx 'enable:BR2_PACKAGE_LIBCURL' "$output/.tdvp-enable.log"
grep -Fqx 'enable:BR2_PACKAGE_LIBCURL_CURL' "$output/.tdvp-enable.log"
grep -Fqx 'disable:BR2_PACKAGE_LIBICONV' "$output/.tdvp-enable.log"
test -f "$stage_root/usr/bin/curl"
test ! -L "$stage_root/usr/bin/curl"
test "$(stat -c '%a' "$stage_root/usr/bin/curl")" = 755
grep -Fqx 'fixture curl command' "$stage_root/usr/bin/curl"
expected_marker=$'format=1\nsource-package=libcurl-4\nbuildroot-package=libcurl\ncommand=/usr/bin/curl'
[[ "$(cat "$stage_root/.tdvp-buildroot-command-libcurl-curl")" == "$expected_marker" ]]

TDVP_FEED_STAGING_ROOT="$stage_root" \
  bash "$leaf_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"
leaf_payload=$(readlink -f -- "$leaf_dir/root")
test -f "$leaf_payload/usr/bin/curl"
test ! -L "$leaf_payload/usr/bin/curl"
test "$(stat -c '%a' "$leaf_payload/usr/bin/curl")" = 755
cmp -s "$stage_root/usr/bin/curl" "$leaf_payload/usr/bin/curl"

if TDVP_FEED_STAGING_ROOT="$stage_root" \
  tdvp_build_archive_library "$package_dir" "$output/host" '' \
  BR2_PACKAGE_LIBCURL libcurl 'libcurl.so*' 'LIBCURL_VERSION = 8.12.1' \
  --enable BR2_PACKAGE_LIBCURL_CURL --stage-command /usr/bin/curl \
  >"$work_root/staging-collision.log" 2>&1; then
  echo 'archive-library overwrote an existing staged command' >&2
  exit 1
fi
grep -Fq 'refusing to replace an existing staged Buildroot command' \
  "$work_root/staging-collision.log"

if tdvp_build_archive_library "$package_dir" "$output/host" '' \
  BR2_PACKAGE_LIBCURL libcurl 'libcurl.so*' 'LIBCURL_VERSION = 8.12.1' \
  --stage-command /usr/lib/curl \
  >"$work_root/unsafe-command.log" 2>&1; then
  echo 'archive-library accepted an unsafe staged command path' >&2
  exit 1
fi
grep -Fq 'archive-library --stage-command requires one clean /usr/bin command path' \
  "$work_root/unsafe-command.log"

if tdvp_build_archive_library "$package_dir" "$output/host" '' \
  BR2_PACKAGE_LIBCURL libcurl 'libcurl.so*' 'LIBCURL_VERSION = 8.12.1' \
  --make-variable 'FIXTURE_BAD=$(touch /tmp/tdvp-archive-library-policy-bad)' \
  >"$work_root/unsafe-make-variable.log" 2>&1; then
  echo 'archive-library accepted an unsafe make variable' >&2
  exit 1
fi
grep -Fq 'archive-library --make-variable requires one safe NAME=value assignment' \
  "$work_root/unsafe-make-variable.log"
test ! -e /tmp/tdvp-archive-library-policy-bad

payload_dir=$(readlink -f -- "$package_dir/root")
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"
rm -f -- "$leaf_dir/root"
rm -rf -- "$leaf_payload"
echo 'Buildroot archive-library staging policy: PASS'
