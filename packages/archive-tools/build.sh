#!/usr/bin/env bash
# Package the full archive toolchain as private executables plus ordinary
# /usr/bin command frontends.  Buildroot intentionally installs tar/gzip in
# /bin to replace BusyBox in a monolithic image; a feed may not replace the
# immutable image, so these wrappers give users normal command names without
# overwriting /bin.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64;
}
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_ARCHIVE_BUILDROOT_OUTPUT:-}")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
for proof in \
  'TAR_VERSION = 1.35' \
  'GZIP_VERSION = 1.13' \
  'BZIP2_VERSION = 1.0.8' \
  'XZ_VERSION = 5.6.4' \
  'ZSTD_VERSION = 1.5.7' \
  'P7ZIP_VERSION = 17.05'; do
  rg -Fqx "$proof" "$tree/package" || { echo "locked Buildroot lacks reviewed source: $proof" >&2; exit 65; }
done

install_root=$(mktemp -d)
cleanup() { rm -rf -- "$install_root"; }
trap cleanup EXIT
tdvp_buildroot_install "$output" "$install_root" \
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

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/libexec/tdvp-archive"
install_tool() {
  local name=$1 source
  for source in "/bin/$name" "/usr/bin/$name"; do
    if [[ -x "$install_root$source" ]]; then
      install -Dm 0755 "$install_root$source" "$payload_dir/usr/libexec/tdvp-archive/$name"
      cat >"$payload_dir/usr/bin/$name" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-archive/$name "\$@"
EOF
      chmod 0755 "$payload_dir/usr/bin/$name"
      return 0
    fi
  done
  echo "archive target install omitted command: $name" >&2
  return 66
}
for command in tar gzip gunzip zcat bzip2 bunzip2 bzcat xz unxz xzcat zstd unzstd zstdcat zip unzip 7za; do
  install_tool "$command"
done
echo "archive-tools payload ready: $payload_dir"
