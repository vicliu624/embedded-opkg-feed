#!/usr/bin/env bash
# Build a source-locked archive command suite without replacing BusyBox. Each
# command uses a collision-free /usr/bin/tdvp-archive-<command> frontend while
# its real ELF stays private below /usr/libexec/tdvp-archive and uses explicitly
# owned shared runtimes.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "$0")" && pwd)
sdk_root=$4
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

if [[ -v TDVP_ARCHIVE_BUILDROOT_OUTPUT && -n "$TDVP_ARCHIVE_BUILDROOT_OUTPUT" ]]; then
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$TDVP_ARCHIVE_BUILDROOT_OUTPUT")
else
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root")
fi
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; exit 65; }

grep -Fqx 'TAR_VERSION = 1.35' "$tree/package/tar/tar.mk"
grep -Fqx 'GZIP_VERSION = 1.13' "$tree/package/gzip/gzip.mk"
grep -Fqx 'BZIP2_VERSION = 1.0.8' "$tree/package/bzip2/bzip2.mk"
grep -Fqx 'XZ_VERSION = 5.6.4' "$tree/package/xz/xz.mk"
grep -Fqx 'ZSTD_VERSION = 1.5.7' "$tree/package/zstd/zstd.mk"
grep -Fqx 'ZIP_VERSION = 3.0' "$tree/package/zip/zip.mk"
grep -Fqx 'UNZIP_VERSION = 6.0' "$tree/package/unzip/unzip.mk"
grep -Fqx 'P7ZIP_VERSION = 17.05' "$tree/package/p7zip/p7zip.mk"

download_dir=
install_root=$(mktemp -d)
payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix=/tmp/tdvp-command-payload.
cleanup() {
  local rc=$?
  rm -rf -- "$install_root"
  [[ -z "$download_dir" ]] || rm -rf -- "$download_dir"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

run_buildroot_install() {
  tdvp_buildroot_install "$output" "$install_root" "$@" \
    --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
    --enable BR2_PACKAGE_TAR \
    --enable BR2_PACKAGE_GZIP \
    --enable BR2_PACKAGE_BZIP2 \
    --enable BR2_PACKAGE_XZ \
    --enable BR2_PACKAGE_ZSTD \
    --enable BR2_PACKAGE_ZIP \
    --enable BR2_PACKAGE_UNZIP \
    --enable BR2_PACKAGE_P7ZIP \
    --enable BR2_PACKAGE_P7ZIP_7ZA \
    --disable BR2_PACKAGE_P7ZIP_7ZR \
    --target bzip2 --target xz --target zstd --target tar --target gzip \
    --target zip --target unzip --target p7zip
}

if [[ -f "$package_dir/source.lock" ]]; then
  download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
  run_buildroot_install --offline-download-dir "$download_dir"
else
  run_buildroot_install
fi

# Build roots may be on Windows drvfs, where mode bits cannot distinguish a
# 0644 runtime data file from a command. Keep this generated payload in /tmp
# and point root/ to it so build-ipk can package the target modes faithfully.
if [[ -L "$payload_link" ]]; then
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  if [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]]; then
    rm -rf -- "$previous_payload"
  fi
fi
rm -rf -- "$payload_link"
payload_dir=$(mktemp -d "$temporary_prefix"XXXXXX)
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/libexec/tdvp-archive"

install_tool() {
  local name=$1 source destination frontend
  for source in "/bin/$name" "/usr/bin/$name"; do
    if [[ -x "$install_root$source" ]]; then
      destination="$payload_dir/usr/libexec/tdvp-archive/$name"
      install -Dm 0755 "$install_root$source" "$destination"
      tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$destination"
      frontend="tdvp-archive-$name"
      cat >"$payload_dir/usr/bin/$frontend" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-archive/$name "\$@"
EOF
      chmod 0755 "$payload_dir/usr/bin/$frontend"
      return 0
    fi
  done
  echo "archive target install omitted command: $name" >&2
  return 66
}

for command in tar gzip gunzip zcat bzip2 bunzip2 bzcat xz unxz xzcat zstd unzstd zstdcat zip unzip 7za; do
  install_tool "$command"
done
payload_ready=1
echo "archive-tools payload ready: $payload_dir"
