#!/usr/bin/env bash
# Transfer the non-ABI libatomic runtime from the exact completed TDVP target.
# This is deliberately not a source-library rebuild: libatomic is emitted by
# the platform's externally pinned Xuantie GCC, so a feed copy is admissible
# only when it is byte-identical to that platform target.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "libatomic-1 does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_LIBATOMIC_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"

grep -Fqx "BR2_TOOLCHAIN_EXTERNAL_PATH=\"$RUNTIME_TOOLCHAIN_PATH\"" "$output/.config" || {
  echo 'matching Buildroot output does not select the reviewed Xuantie toolchain path' >&2
  exit 66
}
for required_config in BR2_TOOLCHAIN_EXTERNAL_GCC_14=y BR2_TOOLCHAIN_HAS_LIBATOMIC=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required toolchain property: $required_config" >&2
    exit 67
  }
done

readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
compiler="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc"
[[ -x "$readelf_tool" && -x "$compiler" ]] || {
  echo 'matching SDK is missing the target compiler or readelf' >&2
  exit 68
}
[[ "$("$compiler" -dumpfullversion -dumpversion)" == "$RUNTIME_TOOLCHAIN_VERSION" ]] || {
  echo 'matching SDK compiler version differs from the reviewed libatomic runtime' >&2
  exit 69
}

target_library_dir="$output/target/usr/lib"
target_library="$target_library_dir/$RUNTIME_LIBRARY_FILE"
target_link="$target_library_dir/libatomic.so.1"
[[ -f "$target_library" && ! -L "$target_library" ]] || {
  echo "matching target omits regular $RUNTIME_LIBRARY_FILE" >&2
  exit 70
}
[[ -L "$target_link" && "$(readlink -- "$target_link")" == "$RUNTIME_LIBRARY_FILE" ]] || {
  echo 'matching target libatomic SONAME link differs from the reviewed target' >&2
  exit 71
}
[[ "$(sha256sum "$target_library" | awk '{print $1}')" == "$RUNTIME_LIBRARY_SHA256" ]] || {
  echo 'matching target libatomic bytes differ from the reviewed runtime transfer' >&2
  exit 72
}
tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$target_library"
"$readelf_tool" -dW "$target_library" | grep -Fq 'Library soname: [libatomic.so.1]' || {
  echo 'matching target libatomic SONAME differs from libatomic.so.1' >&2
  exit 73
}

payload_link="$package_dir/root"
temporary_prefix=/tmp/tdvp-command-payload.
if [[ -e "$payload_link" || -L "$payload_link" ]]; then
  [[ -L "$payload_link" ]] || {
    echo "refusing to replace non-generated payload path: $payload_link" >&2
    exit 74
  }
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]] || {
    echo "refusing to replace unexpected payload target: $previous_payload" >&2
    exit 75
  }
  rm -f -- "$payload_link"
  rm -rf -- "$previous_payload"
fi
payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
mkdir -p -- "$payload_dir/usr/lib"
cp -a -- "$target_link" "$target_library" "$payload_dir/usr/lib/"

# Re-check the copied object and link so the eventual identical-overlay audit
# cannot be bypassed by a mode, link, or post-copy mutation mistake.
[[ "$(readlink -- "$payload_dir/usr/lib/libatomic.so.1")" == "$RUNTIME_LIBRARY_FILE" ]]
[[ "$(sha256sum "$payload_dir/usr/lib/$RUNTIME_LIBRARY_FILE" | awk '{print $1}')" == "$RUNTIME_LIBRARY_SHA256" ]]
tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/lib/$RUNTIME_LIBRARY_FILE"
echo "libatomic-1 payload ready: $payload_dir"
