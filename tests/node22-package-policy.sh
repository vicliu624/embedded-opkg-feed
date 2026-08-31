#!/usr/bin/env bash
# Fast source-level contract for the r10 Node.js source build.  The candidate
# job performs the actual K230 ELF/version and runtime-closure checks; this
# guard prevents an easier but invalid prebuilt or bundled-library route from
# reaching that expensive build.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

for package in \
  libcares libuv libnghttp2 libicudata libicuuc libicui18n libicuio \
  libnode node npm-runtime npm tdvp-nodejs-tools; do
  env_file="$repo_root/packages/$package/package.env"
  test -f "$env_file"
  grep -Fqx "PACKAGE='$package'" "$env_file"
  grep -Fqx "PACKAGE_RELEASES='r10'" "$env_file"
done

grep -Fqx "VERSION='22.23.2-1'" "$repo_root/packages/libnode/package.env"
grep -Fqx "SOURCE_REVISION='aa4c77582be995286fc6e00aaf530dc7ade102a9'" "$repo_root/packages/libnode/package.env"
grep -Fqx "PACKAGE_KIND='shared-library'" "$repo_root/packages/libnode/package.env"
grep -Fqx "PACKAGE_KIND='runtime'" "$repo_root/packages/npm-runtime/package.env"
grep -Fqx "VERSION='10.9.8-1'" "$repo_root/packages/npm-runtime/package.env"
grep -Fqx "VERSION='10.9.8-1'" "$repo_root/packages/npm/package.env"
grep -Fq "PACKAGE_DEPENDS='node (= 22.23.2-1), npm-runtime (= 10.9.8-1), ca-certificates (= 2025.02.1-1)'" "$repo_root/packages/npm/package.env"
grep -Fqx 'libnode.so.127|libnode|22.23.2-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

for owner in \
  'libcares.so.2|libcares|1.34.2-1' \
  'libuv.so.1|libuv|1.50.0-1' \
  'libnghttp2.so.14|libnghttp2|1.64.0-1' \
  'libicudata.so.73|libicudata|73.2-1' \
  'libicuuc.so.73|libicuuc|73.2-1' \
  'libicui18n.so.73|libicui18n|73.2-1' \
  'libicuio.so.73|libicuio|73.2-1'; do
  grep -Fqx "$owner" "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
done

node_build="$repo_root/support/node22-source-build.sh"
grep -Fqx "TDVP_NODE22_VERSION='22.23.2'" "$node_build"
grep -Fqx "TDVP_NODE22_SOURCE_SHA256='cdaed46fcd8923a55974b7bbc7caaadeaaf7aed60cc137e59837b72f575ef641'" "$node_build"
grep -Fq -- '--dest-cpu=riscv64' "$node_build"
grep -Fq -- '--with-intl=system-icu' "$node_build"
for option in --shared --shared-zlib --shared-cares --shared-libuv --shared-nghttp2 --shared-openssl; do
  grep -Fq -- "$option" "$node_build"
done
grep -Fq -- '-static-libstdc++ -static-libgcc' "$node_build"
grep -Fq 'PKG_CONFIG_SYSROOT_DIR="$TDVP_K230_SYSROOT"' "$node_build"
grep -Fq 'GLIBC_[0-9]+' "$node_build"
grep -Fq 'v8-qemu-wrapper' "$node_build"
if grep -Eq '(releases/download.*linux-riscv|linux-riscv64.*\.tar\.(gz|xz)|node-v[0-9].*-linux-)' "$node_build"; then
  echo 'Node 22 recipe must not download a prebuilt target binary' >&2
  exit 1
fi

inputs="$repo_root/support/buildroot-node-inputs.sh"
for symbol in BR2_PACKAGE_C_ARES BR2_PACKAGE_LIBUV BR2_PACKAGE_NGHTTP2 BR2_PACKAGE_ICU; do
  grep -Fq -- "$symbol" "$inputs"
done
echo 'Node 22 package policy test passed'
