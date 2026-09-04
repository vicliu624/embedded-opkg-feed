#!/usr/bin/env bash
# Cross-build the normal Git command and private helper/template runtime from
# the locked Git release. Buildroot's Git recipe supplies the reviewed feature
# choices, but enabling BR2_PACKAGE_GIT would make this desktop SDK rebuild its
# unrelated global package graph instead of a bounded feed source build.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "git-runtime does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_GIT_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'GIT_VERSION = 2.48.1' "$tree/package/git/git.mk" || {
  echo 'locked Buildroot Git version differs from the reviewed recipe' >&2
  exit 66
}
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$tree/package/git/git.hash" || {
  echo 'locked Buildroot Git archive hash differs from the reviewed recipe' >&2
  exit 67
}
for required_config in \
  BR2_PACKAGE_ZLIB=y BR2_PACKAGE_LIBOPENSSL=y BR2_PACKAGE_PCRE2=y \
  BR2_PACKAGE_LIBCURL=y BR2_PACKAGE_EXPAT=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required Git SDK feature: $required_config" >&2
    exit 68
  }
done

: "${TDVP_SOURCE_CACHE_ROOT:?git-runtime requires the verified TDVP source cache}"
cache_archive="$TDVP_SOURCE_CACHE_ROOT/sha256/$SOURCE_ARCHIVE_SHA256/$SOURCE_ARCHIVE"
[[ -f "$cache_archive" && ! -L "$cache_archive" ]] || {
  echo "verified Git archive is absent from source cache: $cache_archive" >&2
  exit 69
}
[[ "$(sha256sum "$cache_archive" | awk '{print $1}')" == "$SOURCE_ARCHIVE_SHA256" ]] || {
  echo 'cached Git archive hash differs from package.env' >&2
  exit 70
}

compiler="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc"
archiver="$sdk_root/bin/riscv64-unknown-linux-gnu-ar"
ranlib="$sdk_root/bin/riscv64-unknown-linux-gnu-ranlib"
pkgconf="$sdk_root/bin/pkgconf"
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
for tool in "$compiler" "$archiver" "$ranlib" "$pkgconf" "$readelf_tool"; do
  [[ -x "$tool" ]] || { echo "matching SDK tool is absent: $tool" >&2; exit 71; }
done
sysroot="$sdk_root/riscv64-buildroot-linux-gnu/sysroot"
[[ -d "$sysroot/usr/include" && -d "$sysroot/usr/lib" && -x "$sysroot/usr/bin/curl-config" ]] || {
  echo "matching SDK sysroot lacks Git headers, libraries, or curl-config: $sysroot" >&2
  exit 72
}
pkgconf_environment=(
  "PKG_CONFIG_SYSROOT_DIR=$sysroot"
  "PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
)
for dependency in openssl libcurl expat libpcre2-8 zlib; do
  env "${pkgconf_environment[@]}" "$pkgconf" --exists "$dependency" || {
    echo "matching SDK pkgconf cannot resolve Git dependency: $dependency" >&2
    exit 73
  }
done
dependency_cflags=$(env "${pkgconf_environment[@]}" "$pkgconf" --cflags \
  openssl libcurl expat libpcre2-8 zlib)
dependency_libs=$(env "${pkgconf_environment[@]}" "$pkgconf" --libs \
  openssl libcurl expat libpcre2-8 zlib)

work_root=$(mktemp -d)
install_root=$(mktemp -d)
payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."
cleanup() {
  local rc=$?
  rm -rf -- "$work_root" "$install_root"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tar -xJf "$cache_archive" -C "$work_root"
source_dir="$work_root/git-${VERSION%-*}"
[[ -f "$source_dir/configure" && -f "$source_dir/Makefile" ]] || {
  echo "locked Git archive did not extract expected source directory: $source_dir" >&2
  exit 74
}

# Keep the known Buildroot transport feature set, but deliberately do not
# compile target Perl/Python/Tcl/Tk/gettext/gitweb output. Those optional front
# ends would need their own separately admitted runtime providers.
(
  cd "$source_dir"
  env CC="$compiler" AR="$archiver" RANLIB="$ranlib" \
    CFLAGS="-O2 -g0 $dependency_cflags" CPPFLAGS="$dependency_cflags" \
    LDFLAGS="-L$sysroot/usr/lib" LIBS="$dependency_libs" \
    PKG_CONFIG="$pkgconf" "${pkgconf_environment[@]}" \
    ac_cv_prog_CURL_CONFIG="$sysroot/usr/bin/curl-config" \
    ac_cv_fread_reads_directories=yes ac_cv_snprintf_returns_bogus=yes \
    ./configure \
      --build="$(gcc -dumpmachine)" \
      --host=riscv64-unknown-linux-gnu \
      --prefix=/usr --exec-prefix=/usr --bindir=/usr/bin \
      --libexecdir=/usr/libexec --datadir=/usr/share \
      --with-openssl --with-libpcre2 --with-curl --with-expat \
      --without-iconv --without-tcltk

  git_make_options=(
    NO_GETTEXT=YesPlease NO_PERL=YesPlease NO_PYTHON=YesPlease
    NO_TCLTK=YesPlease NO_GITWEB=YesPlease NO_INSTALL_HARDLINKS=YesPlease
    INSTALL_SYMLINKS=YesPlease
    CURL_CONFIG="$sysroot/usr/bin/curl-config"
    TEST_PROGRAMS= test_bindir_programs= UNIT_TEST_PROGS= CLAR_TEST_PROG=
    FUZZ_OBJS= FUZZ_PROGRAMS=
  )
  make -j"$(nproc)" "${git_make_options[@]}"
  make DESTDIR="$install_root" "${git_make_options[@]}" install
)

[[ -x "$install_root/usr/bin/git" && -d "$install_root/usr/libexec/git-core" && \
   -d "$install_root/usr/share/git-core/templates" ]] || {
  echo 'Git install omitted its frontend, private helper runtime, or templates' >&2
  exit 75
}
for required_helper in git-remote-http git-submodule; do
  [[ -e "$install_root/usr/libexec/git-core/$required_helper" || \
     -L "$install_root/usr/libexec/git-core/$required_helper" ]] || {
    echo "Git install omitted required transport helper: $required_helper" >&2
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
mkdir -p -- "$payload_dir/usr/libexec/git-core" "$payload_dir/usr/share"
# Retain the normal client/transport helpers and ordinary shell workflow data,
# but do not publish daemon, CGI, shell-login, CVS/SVN/P4/email, Gitweb, or
# browser-launcher programs. They are servers or optional interpreter/desktop
# front ends rather than a K230 Git client requirement. Most porcelain and
# plumbing commands are builtin dispatches in /usr/bin/git; the `git` link
# below is deliberately relative to that leaf package, avoiding a duplicate
# multi-megabyte frontend in git-runtime.
runtime_entries=(
  git
  git-difftool--helper git-filter-branch
  git-http-fetch git-http-push git-imap-send
  git-merge-octopus git-merge-one-file git-merge-resolve git-mergetool
  git-mergetool--lib git-quiltimport git-request-pull
  git-remote-http git-remote-https git-remote-ftp git-remote-ftps
  git-sh-i18n git-sh-i18n--envsubst git-sh-setup git-submodule
)
for runtime_entry in "${runtime_entries[@]}"; do
  source_entry="$install_root/usr/libexec/git-core/$runtime_entry"
  [[ -e "$source_entry" || -L "$source_entry" ]] || {
    echo "Git install omitted selected client runtime entry: $runtime_entry" >&2
    exit 79
  }
  cp -a -- "$source_entry" "$payload_dir/usr/libexec/git-core/$runtime_entry"
done
[[ -L "$payload_dir/usr/libexec/git-core/git" && \
   "$(readlink -- "$payload_dir/usr/libexec/git-core/git")" == '../../bin/git' ]] || {
  echo 'Git runtime frontend link must resolve through the separate git leaf package' >&2
  exit 80
}
cp -a -- "$install_root/usr/libexec/git-core/mergetools" \
  "$payload_dir/usr/libexec/git-core/mergetools"
cp -a -- "$install_root/usr/share/git-core" "$payload_dir/usr/share/git-core"

# Treat every installed target ELF as an independently auditable object. Git
# may use either normal files or relative helper links; only regular ELF files
# can contain dynamic RPATH/RUNPATH tags. A non-ELF executable under git-core
# may only use the platform's POSIX shell, because Perl/Python/Tcl/Tk were
# excluded above. Template hook samples are data copied by git-init for the
# user to inspect or opt into; their own shebangs are not TDVP runtime needs.
while IFS= read -r -d '' candidate; do
  if "$readelf_tool" -h "$candidate" >/dev/null 2>&1; then
    tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$candidate"
    continue
  fi
  if [[ "$candidate" == "$payload_dir/usr/libexec/git-core/"* && -x "$candidate" && \
        "$(head -c2 -- "$candidate")" == '#!' ]]; then
    shebang=$(head -n1 -- "$candidate")
    [[ "$shebang" == '#!/bin/sh' ]] || {
      echo "Git runtime would require an unowned target interpreter: ${candidate#$payload_dir} ($shebang)" >&2
      exit 81
    }
  fi
done < <(find "$payload_dir" -type f -print0 | LC_ALL=C sort -z)

mkdir -p -- "$TDVP_FEED_STAGING_ROOT/usr/bin"
install -m 0755 -- "$install_root/usr/bin/git" "$TDVP_FEED_STAGING_ROOT/usr/bin/git"
payload_ready=1
echo "git-runtime payload ready: $payload_dir"
