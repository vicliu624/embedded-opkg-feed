#!/usr/bin/env bash
# Exercise Wget's reviewed Buildroot option set without a firmware SDK. The
# fixture proves that the command recipe checks its OpenSSL/zlib contract,
# overrides its own optional closure without changing global SDK Kconfig, and
# leaves the SDK config byte identical when the transaction ends.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/wget"
tree="$work_root/buildroot"
output="$work_root/output"
mkdir -p -- \
  "$package_dir" \
  "$fixture_repo/support" \
  "$tree/utils" \
  "$tree/package/wget" \
  "$output/host/bin" \
  "$output/target"
cp -- "$repo_root/packages/wget/build.sh" "$package_dir/build.sh"
cp -- "$repo_root/support/buildroot-command-package.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/package/wget/wget.mk" <<'EOF'
WGET_VERSION = 1.25.0
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
printf '%s:%s\n' "$mode" "$symbol" >>"$(dirname -- "$config_file")/.tdvp-kconfig.log"
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
printf '%s\n' "$@" >>"$output/.tdvp-make.log"
case " $* " in
  *' olddefconfig '*) exit 0 ;;
  *' wget-dirclean '*) exit 0 ;;
  *' wget-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/bin"
    printf 'fixture wget command\n' >"$target_root/usr/bin/wget"
    chmod 0755 -- "$target_root/usr/bin/wget"
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
  -d|-dW) ;;
  *) exit 2 ;;
esac
EOF
chmod 0755 "$output/host/bin/riscv64-unknown-linux-gnu-readelf"
printf '%s\n' \
  'BR2_PACKAGE_OPENSSL=y' \
  'BR2_PACKAGE_LIBOPENSSL=y' \
  'BR2_PACKAGE_ZLIB=y' \
  'ORIGINAL_CONFIG=y' \
  >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"

[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
for record in \
  enable:BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  enable:BR2_PACKAGE_WGET; do
  grep -Fqx "$record" "$output/.tdvp-kconfig.log"
done
grep -Fqx 'WGET_DEPENDENCIES=host-pkgconf openssl zlib' "$output/.tdvp-make.log"
grep -Fqx 'WGET_CONF_OPTS=--without-libpsl --with-ssl openssl --disable-iri --without-libuuid --with-zlib --without-cares --disable-pcre --disable-pcre2' "$output/.tdvp-make.log"

payload_dir=$(readlink -f -- "$package_dir/root")
test -f "$payload_dir/usr/libexec/tdvp-wget/wget"
test ! -L "$payload_dir/usr/libexec/tdvp-wget/wget"
test "$(stat -c '%a' "$payload_dir/usr/libexec/tdvp-wget/wget")" = 755
grep -Fqx 'fixture wget command' "$payload_dir/usr/libexec/tdvp-wget/wget"
test -f "$payload_dir/usr/bin/wget"
grep -Fqx 'exec /usr/libexec/tdvp-wget/wget "$@"' "$payload_dir/usr/bin/wget"
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"

# Missing OpenSSL must fail before the generic Buildroot helper can produce a
# payload, preventing an accidental plaintext-only Wget from entering the feed.
sed -i '/^BR2_PACKAGE_OPENSSL=y$/d' "$output/.config"
if bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host" \
  >"$work_root/missing-openssl.log" 2>&1; then
  echo 'Wget accepted an SDK without the required OpenSSL feature' >&2
  exit 1
fi
grep -Fq 'matching Buildroot output lacks required Wget SDK feature: BR2_PACKAGE_OPENSSL=y' \
  "$work_root/missing-openssl.log"
test ! -e "$package_dir/root"

echo 'Wget Buildroot transaction policy: PASS'
