#!/usr/bin/env bash
# r10 already ships curl. The final IPK carries the exact reviewed command
# from the locked image root, while libcurl development files come from the
# matching immutable SDK.
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

sdk_root=$4
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || {
  echo "matching SDK has no target readelf: $readelf_tool" >&2
  exit 66
}

base_root=${TDVP_FEED_BASE_ROOT:-}
base_command="$base_root/usr/bin/curl"
[[ -n "$base_root" && -f "$base_command" && ! -L "$base_command" ]] || {
  echo 'curl requires TDVP_FEED_BASE_ROOT with the locked image /usr/bin/curl' >&2
  exit 67
}
"$readelf_tool" -h "$base_command" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
  echo 'locked image supplies a non-RISC-V curl command' >&2
  exit 68
}
"$readelf_tool" -d "$base_command" 2>/dev/null | grep -Fq 'Shared library: [libcurl.so.4]' || {
  echo 'locked image curl lacks its reviewed libcurl.so.4 dependency' >&2
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

# The installable package owns the exact command already reviewed in r10.
install -Dm 0755 -- "$base_command" "$payload_dir/usr/bin/curl"
# The locked image command intentionally carries an empty RUNPATH dynamic
# entry.  Rewriting it with the generic ELF normalizer changes otherwise
# identical bytes, so retain the reviewed file verbatim and prove that this
# transfer did not alter it.
cmp -s -- "$base_command" "$payload_dir/usr/bin/curl" || {
  echo 'curl payload transfer changed the locked image command' >&2
  exit 70
}
payload_dir=
trap - ERR
echo 'curl payload ready from locked r10 image command'
