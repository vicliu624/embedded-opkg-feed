#!/usr/bin/env bash
# Exercise lsof's bounded Buildroot transaction without a firmware SDK. It
# verifies MMU preflight, libtirpc exclusion, byte-identical config restoration,
# and the standard package-private command layout.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/lsof"
tree="$work_root/buildroot"
output="$work_root/output"
mkdir -p -- \
  "$package_dir" \
  "$fixture_repo/support" \
  "$tree/utils" \
  "$tree/package/lsof" \
  "$output/host/bin" \
  "$output/target"
cp -- "$repo_root/packages/lsof/build.sh" "$package_dir/build.sh"
cp -- "$repo_root/support/buildroot-command-package.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/package/lsof/lsof.mk" <<'EOF'
LSOF_VERSION = 4.99.4
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
case " $* " in
  *' olddefconfig '*) exit 0 ;;
  *' lsof-dirclean '*) exit 0 ;;
  *' lsof-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/bin"
    printf 'fixture lsof command\n' >"$target_root/usr/bin/lsof"
    chmod 0755 -- "$target_root/usr/bin/lsof"
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
  'BR2_USE_MMU=y' \
  'BR2_PACKAGE_LIBTIRPC=y' \
  'ORIGINAL_CONFIG=y' \
  >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"

[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
for record in \
  enable:BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  enable:BR2_PACKAGE_LSOF \
  disable:BR2_PACKAGE_LIBTIRPC; do
  grep -Fqx "$record" "$output/.tdvp-kconfig.log"
done
payload_dir=$(readlink -f -- "$package_dir/root")
test -f "$payload_dir/usr/libexec/tdvp-lsof/lsof"
test ! -L "$payload_dir/usr/libexec/tdvp-lsof/lsof"
test "$(stat -c '%a' "$payload_dir/usr/libexec/tdvp-lsof/lsof")" = 755
grep -Fqx 'fixture lsof command' "$payload_dir/usr/libexec/tdvp-lsof/lsof"
grep -Fqx 'exec /usr/libexec/tdvp-lsof/lsof "$@"' "$payload_dir/usr/bin/tdvp-lsof"
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"

sed -i '/^BR2_USE_MMU=y$/d' "$output/.config"
if bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host" \
  >"$work_root/missing-mmu.log" 2>&1; then
  echo 'lsof accepted an SDK without the required MMU feature' >&2
  exit 1
fi
grep -Fq 'matching Buildroot output lacks required lsof toolchain feature: BR2_USE_MMU=y' \
  "$work_root/missing-mmu.log"
test ! -e "$package_dir/root"

echo 'lsof Buildroot transaction policy: PASS'
