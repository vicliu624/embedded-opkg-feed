#!/usr/bin/env bash
# Package only sqlite3 staged by libsqlite3-0's immediately preceding locked
# SQLite source build. The command is never copied from the firmware target
# and does not carry a second SQLite shared-library payload.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

stage_root=${TDVP_FEED_STAGING_ROOT:-}
stage_command="$stage_root/usr/bin/sqlite3"
stage_marker="$stage_root/.tdvp-buildroot-command-sqlite-sqlite3"
[[ -n "$stage_root" && -d "$stage_root" && ! -L "$stage_root" && \
   -f "$stage_command" && ! -L "$stage_command" && \
   -f "$stage_marker" && ! -L "$stage_marker" ]] || {
  echo 'sqlite3 requires libsqlite3-0 to stage its locked source-built /usr/bin/sqlite3 first' >&2
  exit 65
}
expected_marker=$'format=1\nsource-package=libsqlite3-0\nbuildroot-package=sqlite\ncommand=/usr/bin/sqlite3'
[[ "$(sed 's/\r$//' "$stage_marker")" == "$expected_marker" ]] || {
  echo 'sqlite3 received an unrecognized libsqlite3-0 Buildroot staging proof' >&2
  exit 66
}

sdk_root=$4
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || {
  echo "matching SDK has no target readelf: $readelf_tool" >&2
  exit 67
}
"$readelf_tool" -h "$stage_command" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
  echo 'libsqlite3-0 staged a non-RISC-V sqlite3 command' >&2
  exit 68
}
"$readelf_tool" -d "$stage_command" 2>/dev/null | grep -Fq 'Shared library: [libsqlite3.so.0]' || {
  echo 'libsqlite3-0 staged sqlite3 without its reviewed libsqlite3.so.0 dependency' >&2
  exit 69
}

payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
cleanup() {
  local rc=$?
  if [[ -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$package_dir/root" && "$(readlink -f -- "$package_dir/root" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$package_dir/root"
    fi
  fi
  exit "$rc"
}
trap cleanup ERR

install -Dm 0755 -- "$stage_command" "$payload_dir/usr/bin/sqlite3"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/bin/sqlite3"
tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/bin/sqlite3"
payload_dir=
trap - ERR
echo 'sqlite3 payload ready from libsqlite3-0 staged source build'
