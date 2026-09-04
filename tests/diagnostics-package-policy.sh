#!/usr/bin/env bash
# The diagnostics bundle is a metadata-only installer profile. It must compose
# independently owned candidates through exact dependencies and never become a
# shortcut for copying an SDK command or a Debian binary.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/tdvp-diagnostics"
env_file="$package_dir/package.env"

grep -Fqx "PACKAGE='tdvp-diagnostics'" "$env_file"
grep -Fqx "VERSION='1.1-1'" "$env_file"
grep -Fqx "PACKAGE_RELEASES='r10'" "$env_file"
grep -Fqx "PACKAGE_DEPENDS='strace (= 6.13-1), htop (= 3.3.0-1), lsof (= 4.99.4-1), iperf3 (= 3.18-1), netcat (= 0.7.1-1)'" "$env_file"
grep -Fqx "PACKAGE_BUILD_DEPENDS='strace htop lsof iperf3 netcat'" "$env_file"
grep -Fqx 'PACKAGE_AUTO_RUNTIME_DEPENDS=0' "$env_file"
grep -Fq "SOURCE_LOCK_EXEMPT_REASON='Installation profile contains only repository-owned documentation and exact dependency metadata; it imports no third-party source.'" "$env_file"
test ! -e "$package_dir/source.lock"
grep -Fq 'independently versioned packages through exact dependencies' "$package_dir/README"
grep -Fq 'without `libtirpc`' "$package_dir/README"
grep -Fq 'optional OpenSSL authentication mode' "$package_dir/README"
grep -Fq 'controlled TCP/UDP listener and connection checks' "$package_dir/README"
grep -Fq 'controlled endpoint' "$package_dir/README"
grep -Fq 'unsigned r10 candidate' "$package_dir/README"
grep -Fq 'tdvp-diagnostics profile payload ready' "$package_dir/build.sh"

echo 'TDVP diagnostics profile policy: PASS'
