#!/usr/bin/env bash
# Package only the curl command from libcurl-4's immediately preceding locked
# Buildroot source build. The command is not rebuilt from a different SDK,
# copied from a firmware root, or taken from a Debian binary package.
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

install -Dm 0755 -- "$stage_command" "$payload_dir/usr/libexec/tdvp-curl/curl"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/libexec/tdvp-curl/curl"
tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/libexec/tdvp-curl/curl"
install -d -m 0755 "$payload_dir/usr/bin"
cat >"$payload_dir/usr/bin/tdvp-curl" <<'EOF'
#!/bin/sh
exec /usr/libexec/tdvp-curl/curl "$@"
EOF
chmod 0755 "$payload_dir/usr/bin/tdvp-curl"
payload_dir=
trap - ERR
echo 'tdvp-curl payload ready from libcurl-4 staged source build'
