#!/usr/bin/env bash
# Package only the public Git frontend produced by git-runtime's immediately
# preceding locked source build. The helpers and templates stay in the separate
# runtime IPK so the runtime boundary remains reviewable.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "git does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -f "$stage_root/usr/bin/git" && ! -L "$stage_root/usr/bin/git" ]] || {
  echo 'git requires git-runtime to stage its locked source-built /usr/bin/git first' >&2
  exit 66
}
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || {
  echo "matching SDK has no target readelf: $readelf_tool" >&2
  exit 67
}
"$readelf_tool" -h "$stage_root/usr/bin/git" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
  echo 'git-runtime staged a non-RISC-V Git frontend' >&2
  exit 68
}

payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."
cleanup() {
  local rc=$?
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

if [[ -e "$payload_link" || -L "$payload_link" ]]; then
  [[ -L "$payload_link" ]] || {
    echo "refusing to replace non-generated payload path: $payload_link" >&2
    exit 69
  }
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]] || {
    echo "refusing to replace unexpected payload target: $previous_payload" >&2
    exit 70
  }
  rm -f -- "$payload_link"
  rm -rf -- "$previous_payload"
fi
payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
install -d -m 0755 -- "$payload_dir/usr/bin"
install -m 0755 -- "$stage_root/usr/bin/git" "$payload_dir/usr/bin/git"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/bin/git"
payload_ready=1
echo "git payload ready: $payload_dir"
