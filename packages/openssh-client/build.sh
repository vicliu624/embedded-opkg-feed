#!/usr/bin/env bash
# Cross-build the normal OpenSSH client tools from the locked upstream archive.
# Buildroot's OpenSSH recipe informs these options, but invoking its target
# package would pull this desktop SDK's unrelated PAM/server closure into a
# client-only feed package.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "openssh-client does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_OPENSSH_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'OPENSSH_VERSION_MAJOR = 9.9' "$tree/package/openssh/openssh.mk" || {
  echo 'locked Buildroot OpenSSH major version differs from the reviewed recipe' >&2
  exit 66
}
grep -Fqx 'OPENSSH_VERSION_MINOR = p2' "$tree/package/openssh/openssh.mk" || {
  echo 'locked Buildroot OpenSSH update version differs from the reviewed recipe' >&2
  exit 67
}
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" \
  "$tree/package/openssh/openssh.hash" || {
  echo 'locked Buildroot OpenSSH archive hash differs from the reviewed recipe' >&2
  exit 68
}
for required_config in BR2_PACKAGE_LIBOPENSSL=y BR2_PACKAGE_ZLIB=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required SDK feature: $required_config" >&2
    exit 69
  }
done

: "${TDVP_SOURCE_CACHE_ROOT:?openssh-client requires the verified TDVP source cache}"
cache_archive="$TDVP_SOURCE_CACHE_ROOT/sha256/$SOURCE_ARCHIVE_SHA256/$SOURCE_ARCHIVE"
[[ -f "$cache_archive" && ! -L "$cache_archive" ]] || {
  echo "verified OpenSSH archive is absent from source cache: $cache_archive" >&2
  exit 70
}
[[ "$(sha256sum "$cache_archive" | awk '{print $1}')" == "$SOURCE_ARCHIVE_SHA256" ]] || {
  echo 'cached OpenSSH archive hash differs from package.env' >&2
  exit 71
}

compiler="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc"
archiver="$sdk_root/bin/riscv64-unknown-linux-gnu-ar"
ranlib="$sdk_root/bin/riscv64-unknown-linux-gnu-ranlib"
pkgconf="$sdk_root/bin/pkgconf"
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
for tool in "$compiler" "$archiver" "$ranlib" "$pkgconf" "$readelf_tool"; do
  [[ -x "$tool" ]] || { echo "matching SDK tool is absent: $tool" >&2; exit 72; }
done
sysroot="$sdk_root/riscv64-buildroot-linux-gnu/sysroot"
[[ -d "$sysroot/usr/include" && -d "$sysroot/usr/lib" ]] || {
  echo "matching SDK sysroot is incomplete: $sysroot" >&2
  exit 73
}
pkgconf_environment=(
  "PKG_CONFIG_SYSROOT_DIR=$sysroot"
  "PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
)
openssl_cflags=$(env "${pkgconf_environment[@]}" "$pkgconf" --cflags openssl)
openssl_libs=$(env "${pkgconf_environment[@]}" "$pkgconf" --libs openssl)
[[ -n "$openssl_libs" ]] || { echo 'matching SDK pkgconf cannot resolve OpenSSL' >&2; exit 74; }

work_root=$(mktemp -d)
payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix=/tmp/tdvp-command-payload.
cleanup() {
  local rc=$?
  rm -rf -- "$work_root"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tar -xzf "$cache_archive" -C "$work_root"
source_dir="$work_root/openssh-${VERSION%-*}"
[[ -f "$source_dir/configure" ]] || {
  echo "locked OpenSSH archive did not extract expected source directory: $source_dir" >&2
  exit 75
}

# These are the relevant reviewed Buildroot options, intentionally with no
# PAM, server, SELinux, setuid helper, or /etc/ssh installation path.  The
# output remains a normal client/file-transfer/agent tool set.
(
  cd "$source_dir"
  env CC="$compiler" AR="$archiver" RANLIB="$ranlib" LD="$compiler" \
    CFLAGS="-O2 -g0 $openssl_cflags" CPPFLAGS="$openssl_cflags" \
    LDFLAGS="-L$sysroot/usr/lib" LIBS="$openssl_libs" \
    ./configure \
      --build="$(gcc -dumpmachine)" \
      --host=riscv64-unknown-linux-gnu \
      --prefix=/usr --bindir=/usr/bin --libexecdir=/usr/libexec \
      --sysconfdir=/etc/ssh --with-default-path=/usr/bin:/usr/sbin \
      --with-sandbox=no --without-ssl-engine \
      --disable-lastlog --disable-utmp --disable-utmpx --disable-wtmp --disable-wtmpx \
      --disable-strip
  make -j"$(nproc)"
)

# Keep the complete source-built client set, but never claim the firmware's
# ordinary /usr/bin/{ssh,scp,sftp,ssh-agent,ssh-add} paths. Each ELF is
# private and its tdvp-* wrapper is a distinct, deny-overlay-protected path.
required_paths=(ssh scp sftp ssh-agent ssh-add)
for program in "${required_paths[@]}"; do
  [[ -x "$source_dir/$program" ]] || {
    echo "OpenSSH client build omitted executable: $program" >&2
    exit 76
  }
done

if [[ -e "$payload_link" || -L "$payload_link" ]]; then
  [[ -L "$payload_link" ]] || {
    echo "refusing to replace non-generated payload path: $payload_link" >&2
    exit 77
  }
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]] || {
    echo "refusing to replace unexpected payload target: $previous_payload" >&2
    exit 78
  }
  rm -f -- "$payload_link"
  rm -rf -- "$previous_payload"
fi
payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
mkdir -p -- "$payload_dir/usr/libexec/tdvp-openssh-client" "$payload_dir/usr/bin"
for program in "${required_paths[@]}"; do
  cp -a -- "$source_dir/$program" "$payload_dir/usr/libexec/tdvp-openssh-client/$program"
done
while IFS= read -r elf; do
  tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$elf"
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$elf"
done < <(find "$payload_dir/usr/libexec/tdvp-openssh-client" -type f -perm -u+x -print | LC_ALL=C sort)
for program in "${required_paths[@]}"; do
  wrapper_name="tdvp-${program}"
  cat >"$payload_dir/usr/bin/$wrapper_name" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-openssh-client/$program "\$@"
EOF
  chmod 0755 -- "$payload_dir/usr/bin/$wrapper_name"
done
[[ ! -e "$payload_dir/etc/ssh" ]] || { echo 'openssh-client must not package /etc/ssh' >&2; exit 80; }
payload_ready=1
echo "tdvp-openssh-client payload ready from locked OpenSSH source build: $payload_dir"
