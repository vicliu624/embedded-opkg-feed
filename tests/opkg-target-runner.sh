#!/usr/bin/env bash
# Use the actual candidate image's package manager in isolated transaction tests.
set -Eeuo pipefail
target_root=$(realpath -e -- "${TDVP_TEST_TARGET_ROOT:?}")
[[ -x "$target_root/usr/bin/opkg" && -f "$target_root/usr/share/tdvp/opkg/image-base.json" ]] || exit 65
exec qemu-riscv64 -L "$target_root" "$target_root/usr/bin/opkg" "$@"
