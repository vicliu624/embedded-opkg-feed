#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/verify-r10-candidate-cohort.sh"
cohort="$repo_root/support/r10-candidate-cohort.sh"
bash -n "$script"
bash -n "$cohort"
for entry in libevent tmux dialog ncdu pv netcat iperf3 lsof sqlite3 bc coreutils mtools dosfstools; do grep -Fq "$entry" "$cohort"; done
grep -Fq 'BR2_TOOLCHAIN_HAS_ATOMIC=y' "$script"
grep -Fq 'BR2_PACKAGE_LIBOPENSSL=y' "$script"
grep -Fq 'BR2_PACKAGE_READLINE=y' "$script"
grep -Fq 'BR2_PACKAGE_SQLITE=y' "$script"
grep -Fq 'archive is absent from cache' "$script"
grep -Fq 'builds, signs, installs, and publishes nothing' "$script"
echo 'r10 candidate cohort preflight policy: PASS'
