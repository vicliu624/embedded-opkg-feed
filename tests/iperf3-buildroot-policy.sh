#!/usr/bin/env bash
# Exercise iperf3's low-closure Buildroot transaction without a firmware SDK.
# It proves that required toolchain capabilities are checked, optional OpenSSL
# is disabled, the input config is restored exactly, and the public command is
# a wrapper around the package-private target executable.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/iperf3"
tree="$work_root/buildroot"
output="$work_root/output"
mkdir -p -- \
  "$package_dir" \
  "$fixture_repo/support" \
  "$tree/utils" \
  "$tree/package/iperf3" \
  "$output/host/bin" \
  "$output/target"
cp -- "$repo_root/packages/iperf3/build.sh" "$package_dir/build.sh"
cp -- "$repo_root/support/buildroot-command-package.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/package/iperf3/iperf3.mk" <<'EOF'
IPERF3_VERSION = 3.18
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
printf '%s\n' "$*" >>"$output/.tdvp-make.log"
case " $* " in
  *' olddefconfig '*) exit 0 ;;
  *' iperf3-dirclean '*) exit 0 ;;
  *' iperf3-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/bin"
    printf 'fixture iperf3 command\n' >"$target_root/usr/bin/iperf3"
    chmod 0755 -- "$target_root/usr/bin/iperf3"
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
  'BR2_TOOLCHAIN_HAS_ATOMIC=y' \
  'BR2_TOOLCHAIN_HAS_THREADS=y' \
  'BR2_PACKAGE_OPENSSL=y' \
  'ORIGINAL_CONFIG=y' \
  >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"

[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
for record in \
  enable:BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  enable:BR2_PACKAGE_IPERF3; do
  grep -Fqx "$record" "$output/.tdvp-kconfig.log"
done
grep -Fq 'IPERF3_CONF_OPTS=--without-openssl --disable-shared --enable-static' "$output/.tdvp-make.log"
grep -Fq 'IPERF3_DEPENDENCIES=' "$output/.tdvp-make.log"
payload_dir=$(readlink -f -- "$package_dir/root")
test -f "$payload_dir/usr/libexec/tdvp-iperf3/iperf3"
test ! -L "$payload_dir/usr/libexec/tdvp-iperf3/iperf3"
test "$(stat -c '%a' "$payload_dir/usr/libexec/tdvp-iperf3/iperf3")" = 755
grep -Fqx 'fixture iperf3 command' "$payload_dir/usr/libexec/tdvp-iperf3/iperf3"
grep -Fqx 'exec /usr/libexec/tdvp-iperf3/iperf3 "$@"' "$payload_dir/usr/bin/iperf3"
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"

sed -i '/^BR2_TOOLCHAIN_HAS_ATOMIC=y$/d' "$output/.config"
if bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host" \
  >"$work_root/missing-atomic.log" 2>&1; then
  echo 'iperf3 accepted an SDK without required atomic support' >&2
  exit 1
fi
grep -Fq 'matching Buildroot output lacks required iperf3 toolchain feature: BR2_TOOLCHAIN_HAS_ATOMIC=y' \
  "$work_root/missing-atomic.log"
test ! -e "$package_dir/root"

echo 'iperf3 Buildroot transaction policy: PASS'
