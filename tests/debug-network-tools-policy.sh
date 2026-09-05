#!/usr/bin/env bash
# Keep the first post-r10 tool expansion locked, namespaced, and free of
# ambient SDK debug-root or libmnl ownership.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing debug-network-tools policy entry in $path: $pattern" >&2
    exit 1
  }
}

gdb_dir="$repo_root/packages/gdbserver"
expect_line "^PACKAGE='gdbserver'$" "$gdb_dir/package.env"
expect_line "^VERSION='15[.]1-1'$" "$gdb_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$gdb_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$gdb_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$gdb_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$gdb_dir/package.env"
expect_line "^UPSTREAM_NAME='GNU gdbserver'$" "$gdb_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='gdb-15[.]1[.]tar[.]xz'$" "$gdb_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='38254eacd4572134bca9c5a5aa4d4ca564cbbd30c369d881f733fb6b903354f2'$" "$gdb_dir/source.lock"
grep -Fq "TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_GDB_SERVER'" "$gdb_dir/build.sh"
grep -Fq 'GDB_POST_INSTALL_TARGET_HOOKS=' "$gdb_dir/build.sh"
grep -Fq 'GDB_VERSION=15.1' "$gdb_dir/build.sh"
grep -Fq 'BR2_PACKAGE_GDB_DEBUGGER BR2_PACKAGE_GDB_TUI BR2_PACKAGE_GDB_PYTHON' "$gdb_dir/build.sh"
grep -Fq 'gdbserver=tdvp-gdbserver' "$gdb_dir/build.sh"
if grep -Eq '/usr/bin/gdbserver|apt|dpkg|debian' "$gdb_dir/build.sh"; then
  echo 'gdbserver build must not publish an ordinary gdbserver, mutate SDK debug-root, or import a Debian binary' >&2
  exit 1
fi

ethtool_dir="$repo_root/packages/ethtool"
expect_line "^PACKAGE='ethtool'$" "$ethtool_dir/package.env"
expect_line "^VERSION='6[.]14-1'$" "$ethtool_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$ethtool_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$ethtool_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$ethtool_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$ethtool_dir/package.env"
expect_line "^UPSTREAM_NAME='ethtool'$" "$ethtool_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='ethtool-6[.]14[.]tar[.]xz'$" "$ethtool_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='9338bb00e492878d3bbe3cd2894e60db35813634c208db0b20f5c7ee84da69b1'$" "$ethtool_dir/source.lock"
grep -Fq 'ETHTOOL_CONF_OPTS=--disable-pretty-dump --disable-netlink' "$ethtool_dir/build.sh"
grep -Fq 'ETHTOOL_DEPENDENCIES=' "$ethtool_dir/build.sh"
grep -Fq 'ethtool=tdvp-ethtool' "$ethtool_dir/build.sh"
if grep -Eq '/usr/bin/ethtool|apt|dpkg|debian' "$ethtool_dir/build.sh"; then
  echo 'ethtool build must not publish an ordinary ethtool or import a Debian binary' >&2
  exit 1
fi

grep -Fq 'TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS' "$repo_root/support/buildroot-command-package.sh"
grep -Fq 'debug-network-tools)' "$workflow"
grep -Fq 'package_args=(--package gdbserver --package ethtool)' "$workflow"
grep -Fq 'expected_packages=(gdbserver ethtool)' "$workflow"
grep -Fq 'bash ./tests/debug-network-tools-policy.sh' "$workflow"

echo 'locked gdbserver/ethtool debug-network policy: PASS'
