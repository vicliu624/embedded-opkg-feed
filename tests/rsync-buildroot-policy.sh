#!/usr/bin/env bash
# Exercise rsync's bounded Buildroot configuration and local patch comparison
# without a firmware SDK or any upstream download.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/rsync"
tree="$work_root/buildroot"
output="$work_root/output"
mkdir -p -- \
  "$package_dir/patches" \
  "$fixture_repo/support" \
  "$tree/utils" \
  "$tree/package/rsync" \
  "$output/host/bin" \
  "$output/target"
cp -- "$repo_root/packages/rsync/build.sh" "$package_dir/build.sh"
cp -- "$repo_root/packages/rsync/patches/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch" \
  "$package_dir/patches/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"
cp -- "$repo_root/packages/rsync/patches/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch" \
  "$tree/package/rsync/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"
cp -- "$repo_root/support/buildroot-command-package.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/package/rsync/rsync.mk" <<'EOF'
RSYNC_VERSION = 3.4.1
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
  *' rsync-dirclean '*) exit 0 ;;
  *' rsync-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/bin"
    printf 'fixture rsync command\n' >"$target_root/usr/bin/rsync"
    chmod 0755 -- "$target_root/usr/bin/rsync"
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
  'BR2_PACKAGE_ZLIB=y' \
  'BR2_PACKAGE_ACL=y' \
  'BR2_PACKAGE_LZ4=y' \
  'BR2_PACKAGE_OPENSSL=y' \
  'BR2_PACKAGE_XXHASH=y' \
  'BR2_PACKAGE_ZSTD=y' \
  'ORIGINAL_CONFIG=y' \
  >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"

[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
for record in \
  enable:BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  enable:BR2_PACKAGE_RSYNC \
  disable:BR2_PACKAGE_ACL \
  disable:BR2_PACKAGE_LZ4 \
  disable:BR2_PACKAGE_OPENSSL \
  disable:BR2_PACKAGE_XXHASH \
  disable:BR2_PACKAGE_ZSTD; do
  grep -Fqx "$record" "$output/.tdvp-kconfig.log"
done
payload_dir=$(readlink -f -- "$package_dir/root")
test -f "$payload_dir/usr/libexec/tdvp-rsync/rsync"
test ! -L "$payload_dir/usr/libexec/tdvp-rsync/rsync"
test "$(stat -c '%a' "$payload_dir/usr/libexec/tdvp-rsync/rsync")" = 755
grep -Fqx 'fixture rsync command' "$payload_dir/usr/libexec/tdvp-rsync/rsync"
grep -Fqx 'exec /usr/libexec/tdvp-rsync/rsync "$@"' "$payload_dir/usr/bin/rsync"
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"

printf '%s\n' '# fixture patch drift' >> \
  "$tree/package/rsync/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"
if bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host" \
  >"$work_root/patch-drift.log" 2>&1; then
  echo 'rsync accepted a Buildroot patch that differs from its reviewed record' >&2
  exit 1
fi
grep -Fq 'locked rsync patch differs from the matching Buildroot tree' \
  "$work_root/patch-drift.log"
test ! -e "$package_dir/root"

sed -i '/^BR2_PACKAGE_ZLIB=y$/d' "$output/.config"
if bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host" \
  >"$work_root/missing-zlib.log" 2>&1; then
  echo 'rsync accepted an SDK without the required zlib feature' >&2
  exit 1
fi
grep -Fq 'matching Buildroot output lacks required rsync SDK feature: BR2_PACKAGE_ZLIB=y' \
  "$work_root/missing-zlib.log"
test ! -e "$package_dir/root"

echo 'rsync Buildroot transaction policy: PASS'
