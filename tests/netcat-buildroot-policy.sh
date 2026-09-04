#!/usr/bin/env bash
# Exercise netcat's private command packaging and config restoration without
# a matching firmware SDK or any upstream network fetch.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

fixture_repo="$work_root/repo"
package_dir="$fixture_repo/packages/netcat"
tree="$work_root/buildroot"
output="$work_root/output"
mkdir -p -- "$package_dir" "$fixture_repo/support" "$tree/utils" \
  "$tree/package/netcat" "$output/host/bin" "$output/target"
cp -- "$repo_root/packages/netcat/build.sh" "$package_dir/build.sh"
cp -- "$repo_root/support/buildroot-command-package.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/buildroot-feed-session.sh" "$fixture_repo/support/"
cp -- "$repo_root/support/elf-runtime-policy.sh" "$fixture_repo/support/"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
printf '%s\n' 'NETCAT_VERSION = 0.7.1' >"$tree/package/netcat/netcat.mk"
cat >"$tree/utils/config" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
config_file= mode= symbol=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) config_file=$2; shift 2 ;;
    --enable|--disable) mode=${1#--}; symbol=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s:%s\n' "$mode" "$symbol" >>"$(dirname -- "$config_file")/.tdvp-kconfig.log"
case "$mode" in enable) printf '%s=y\n' "$symbol" >>"$config_file" ;; disable) sed -i "/^${symbol}=y$/d" "$config_file" ;; *) exit 2 ;; esac
EOF
chmod 0755 "$tree/utils/config"
cat >"$output/Makefile" <<EOF
MAKEARGS := -C $tree
EOF
cat >"$output/host/bin/make" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output= target_root= previous=
for argument in "$@"; do
  if [[ "$previous" == '-C' ]]; then output=$argument; previous=; continue; fi
  case "$argument" in TARGET_DIR=*) target_root=${argument#TARGET_DIR=} ;; esac
  previous=$argument
done
[[ -n "$output" ]] || exit 2
case " $* " in
  *' olddefconfig '*) exit 0 ;;
  *' netcat-dirclean '*) exit 0 ;;
  *' netcat-install-target '*)
    [[ -n "$target_root" ]] || exit 3
    mkdir -p -- "$target_root/usr/bin"
    printf 'fixture netcat command\n' >"$target_root/usr/bin/nc"
    chmod 0755 -- "$target_root/usr/bin/nc"
    exit 0 ;;
esac
exit 4
EOF
chmod 0755 "$output/host/bin/make"
cat >"$output/host/bin/riscv64-unknown-linux-gnu-readelf" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in -h) printf '%s\n' '  Machine:                           RISC-V' ;; -d|-dW) ;; *) exit 2 ;; esac
EOF
chmod 0755 "$output/host/bin/riscv64-unknown-linux-gnu-readelf"
printf '%s\n' 'ORIGINAL_CONFIG=y' >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')

bash "$package_dir/build.sh" --platform tdvp-k230-r1 --sdk-root "$output/host"
[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
grep -Fqx 'enable:BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$output/.tdvp-kconfig.log"
grep -Fqx 'enable:BR2_PACKAGE_NETCAT' "$output/.tdvp-kconfig.log"
payload_dir=$(readlink -f -- "$package_dir/root")
test -f "$payload_dir/usr/libexec/tdvp-netcat/nc"
test ! -L "$payload_dir/usr/libexec/tdvp-netcat/nc"
grep -Fqx 'fixture netcat command' "$payload_dir/usr/libexec/tdvp-netcat/nc"
grep -Fqx 'exec /usr/libexec/tdvp-netcat/nc "$@"' "$payload_dir/usr/bin/nc"
rm -f -- "$package_dir/root"
rm -rf -- "$payload_dir"
echo 'netcat Buildroot transaction policy: PASS'
