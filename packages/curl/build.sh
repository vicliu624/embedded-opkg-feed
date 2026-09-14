#!/usr/bin/env bash
# Use libcurl-4's immediately preceding locked Buildroot source build to
# populate the matching SDK/sysroot. r10 already ships curl, so the final IPK
# carries the exact reviewed command from the locked image root.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "curl does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

stage_root=${TDVP_FEED_STAGING_ROOT:-}
stage_command="$stage_root/usr/bin/curl"
stage_marker="$stage_root/.tdvp-buildroot-command-libcurl-curl"
[[ -n "$stage_root" && -d "$stage_root" && ! -L "$stage_root" && \
   -f "$stage_command" && ! -L "$stage_command" && \
   -f "$stage_marker" && ! -L "$stage_marker" ]] || {
  echo 'curl requires libcurl-4 to stage its locked source-built /usr/bin/curl first' >&2
  exit 66
}
expected_marker=$'format=1\nsource-package=libcurl-4\nbuildroot-package=libcurl\ncommand=/usr/bin/curl'
[[ "$(sed 's/\r$//' "$stage_marker")" == "$expected_marker" ]] || {
  echo 'curl received an unrecognized libcurl-4 Buildroot staging proof' >&2
  exit 67
}

sdk_root=$4
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || {
  echo "matching SDK has no target readelf: $readelf_tool" >&2
  exit 68
}
"$readelf_tool" -h "$stage_command" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
  echo 'libcurl-4 staged a non-RISC-V curl command' >&2
  exit 69
}
"$readelf_tool" -d "$stage_command" 2>/dev/null | grep -Fq 'Shared library: [libcurl.so.4]' || {
  echo 'libcurl-4 staged curl without its reviewed libcurl.so.4 dependency' >&2
  exit 70
}

base_root=${TDVP_FEED_BASE_ROOT:-}
base_command="$base_root/usr/bin/curl"
[[ -n "$base_root" && -f "$base_command" && ! -L "$base_command" ]] || {
  echo 'curl requires TDVP_FEED_BASE_ROOT with the locked image /usr/bin/curl' >&2
  exit 71
}
"$readelf_tool" -h "$base_command" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
  echo 'locked image supplies a non-RISC-V curl command' >&2
  exit 72
}
"$readelf_tool" -d "$base_command" 2>/dev/null | grep -Fq 'Shared library: [libcurl.so.4]' || {
  echo 'locked image curl lacks its reviewed libcurl.so.4 dependency' >&2
  exit 73
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

# The source-built command remains in the staging proof for build-time use.
# The installable package owns the exact command already reviewed in r10.
install -Dm 0755 -- "$base_command" "$payload_dir/usr/bin/curl"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/bin/curl"
tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/bin/curl"
payload_dir=
trap - ERR
echo 'curl payload ready from libcurl-4 staged source build'
