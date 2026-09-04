#!/usr/bin/env bash
# Fast source-level contract for the r10 Node.js source build.  The candidate
# job performs the actual K230 ELF/version and runtime-closure checks; this
# guard prevents an easier but invalid prebuilt or bundled-library route from
# reaching that expensive build.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
owner_map=$(sed 's/\r$//' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv")

for package in \
  libcares libuv libnghttp2 libicudata libicuuc libicui18n libicuio \
  libnode node npm-runtime npm tdvp-nodejs-tools; do
  env_file="$repo_root/packages/$package/package.env"
  test -f "$env_file"
  grep -Fqx "PACKAGE='$package'" "$env_file"
  grep -Fqx "PACKAGE_RELEASES='r10'" "$env_file"
done

for package in \
  libcares libuv libnghttp2 libicudata libicuuc libicui18n libicuio \
  libnode node npm-runtime npm; do
  test -f "$repo_root/packages/$package/source.lock"
  bash "$repo_root/scripts/verify-source-lock.sh" \
    --package-dir "$repo_root/packages/$package" >/dev/null
done

grep -Fqx "VERSION='22.23.2-1'" "$repo_root/packages/libnode/package.env"
grep -Fqx "SOURCE_REVISION='aa4c77582be995286fc6e00aaf530dc7ade102a9'" "$repo_root/packages/libnode/package.env"
grep -Fqx "PACKAGE_KIND='shared-library'" "$repo_root/packages/libnode/package.env"
grep -Fqx "PACKAGE_DEPENDS='libcares (= 1.34.2-1), libuv (= 1.51.0-1), libnghttp2 (= 1.64.0-1), libicui18n (= 73.2-1)'" "$repo_root/packages/libnode/package.env"
grep -Fqx "PACKAGE_KIND='runtime'" "$repo_root/packages/npm-runtime/package.env"
grep -Fqx "VERSION='10.9.8-1'" "$repo_root/packages/npm-runtime/package.env"
grep -Fqx "VERSION='10.9.8-1'" "$repo_root/packages/npm/package.env"
grep -Fq "PACKAGE_DEPENDS='node (= 22.23.2-1), npm-runtime (= 10.9.8-1), ca-certificates (= 2025.02.1-1)'" "$repo_root/packages/npm/package.env"
grep -Fq "SOURCE_LOCK_EXEMPT_REASON='Installation profile contains only repository-owned documentation and exact dependency metadata; it imports no third-party source.'" "$repo_root/packages/tdvp-nodejs-tools/package.env"
grep -Fqx 'libnode.so.127|libnode|22.23.2-1' <<<"$owner_map"

for owner in \
  'libcares.so.2|libcares|1.34.2-1' \
  'libuv.so.1|libuv|1.51.0-1' \
  'libnghttp2.so.14|libnghttp2|1.64.0-1' \
  'libicudata.so.73|libicudata|73.2-1' \
  'libicuuc.so.73|libicuuc|73.2-1' \
  'libicui18n.so.73|libicui18n|73.2-1' \
  'libicuio.so.73|libicuio|73.2-1'; do
  grep -Fqx "$owner" <<<"$owner_map"
done

node_build="$repo_root/support/node22-source-build.sh"
ipk_build="$repo_root/scripts/build-ipk.sh"
grep -Fq 'sub(/\r$/, "", version)' "$ipk_build"
grep -Fqx "TDVP_NODE22_VERSION='22.23.2'" "$node_build"
grep -Fqx "TDVP_NODE22_SOURCE_SHA256='cdaed46fcd8923a55974b7bbc7caaadeaaf7aed60cc137e59837b72f575ef641'" "$node_build"
grep -Fq 'tdvp_source_archive_locked_file "$package_dir"' "$node_build"
grep -Fq -- '--dest-cpu=riscv64' "$node_build"
grep -Fq -- '--with-intl=system-icu' "$node_build"
for option in --shared --shared-zlib --shared-cares --shared-libuv --shared-nghttp2 --shared-openssl; do
  grep -Fq -- "$option" "$node_build"
done
grep -Fq -- '-static-libstdc++ -static-libgcc' "$node_build"
grep -Fq 'PKG_CONFIG_SYSROOT_DIR="$stage_root"' "$node_build"
grep -Fq '$stage_root/usr/lib/pkgconfig' "$node_build"
grep -Fq 'target_flags="--sysroot=$TDVP_K230_SYSROOT -I$stage_root/usr/include' "$node_build"
grep -Fq "export CPPFLAGS=''" "$node_build"
grep -Fq '.tdvp-direct-source-$input_marker' "$node_build"
grep -Fq 'GLIBC_[0-9]+' "$node_build"
grep -Fq 'v8-qemu-wrapper' "$node_build"
grep -Fq 'grep -Fq '\''RISC-V'\''' "$node_build"
grep -Fq 'TDVP_NODE22_HOST_PYTHON' "$node_build"
grep -Fq 'TDVP_NODE22_HOST_CC' "$node_build"
grep -Fq 'TDVP_NODE22_HOST_CXX' "$node_build"
grep -Fq 'native GCC/G++ >= 10 for V8 host generators' "$node_build"
grep -Fq 'matching Buildroot host ICU 73.2 input' "$node_build"
grep -Fq 'TDVP_NODE22_HOST_ICU_LIBRARIES' "$node_build"
grep -Fq 'TDVP_NODE22_HOST_LIBUV_LIBRARIES' "$node_build"
grep -Fq 'LIBUV_BUILD_TESTS=OFF' "$node_build"
grep -Fq 'host_uv_library="$host_uv_build/libuv.a"' "$node_build"
grep -Fq 'riscv64-unknown-linux-gnu-gcc' "$node_build"
grep -Fq '/opt/tdvp-qemu/qemu-riscv64-static' "$node_build"
grep -Fq 'patches/node22-lazy-bz2-import.patch' "$node_build"
grep -Fq 'make -j"$jobs" JOBS="$jobs"' "$node_build"
grep -Fq 'install_root="$build_root/install-root"' "$node_build"
grep -Fq '"$TDVP_K230_READELF" -h "$elf" >/dev/null 2>&1 || continue' "$node_build"
grep -Fq 'tdvp_remove_elf_runtime_search_paths "$TDVP_K230_READELF" "$elf"' "$node_build"
grep -Fq 'tdvp_assert_elf_without_runtime_search_path "$TDVP_K230_READELF" "$elf"' "$node_build"
for package in libnode node npm-runtime npm; do
  grep -Fq 'import bz2' "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
  grep -Fq "'_toolset!=\"host\"'" "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
  grep -Fq "output.setdefault('target_conditions', [])" "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
  grep -Fq 'TDVP_NODE22_HOST_ICU_LIBRARIES' "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
  grep -Fq "'deps/uv/include'" "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
  grep -Fq 'TDVP_NODE22_HOST_LIBUV_LIBRARIES' "$repo_root/packages/$package/patches/node22-lazy-bz2-import.patch"
done
if grep -Eq '(releases/download.*linux-riscv|linux-riscv64.*\.tar\.(gz|xz)|node-v[0-9].*-linux-)' "$node_build"; then
  echo 'Node 22 recipe must not download a prebuilt target binary' >&2
  exit 1
fi

for package in libcares libuv libnghttp2; do
  build="$repo_root/packages/$package/build.sh"
  grep -Fq 'tdvp_build_direct_archive_library' "$build"
  if grep -Fq 'buildroot-node-inputs.sh' "$build"; then
    echo "$package must not materialise its public ABI from a Buildroot target installation" >&2
    exit 1
  fi
done
inputs="$repo_root/support/buildroot-node-inputs.sh"
grep -Fq 'tdvp_prepare_node22_icu_inputs' "$inputs"
grep -Fq 'BR2_PACKAGE_ICU' "$inputs"
if grep -Eq 'BR2_PACKAGE_(C_ARES|LIBUV|NGHTTP2)' "$inputs"; then
  echo 'ICU staging helper must not rebuild direct-source Node providers' >&2
  exit 1
fi
echo 'Node 22 package policy test passed'
