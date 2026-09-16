#!/usr/bin/env bash
# Source-build an individual component with the released application SDK.
# The SDK and image remain read-only; build dependencies live in private staging.
set -Eeuo pipefail

tdvp_sdk_install() (
  set -Eeuo pipefail
  local package_dir=$1 sdk_root=$2 component=$3 install_root=$4
  local repo_root work source_root sysroot jobs archive
  repo_root=$(cd -- "$package_dir/../.." && pwd)
  source "$repo_root/support/source-archive-library.sh"
  work=$(mktemp -d /tmp/tdvp-sdk-build.XXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work/source" "$work/sysroot" "$install_root"
  local source_name
  source_name=${TDVP_SDK_SOURCE_ARCHIVE:-$(bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" --emit-artifacts | sed -n '1p' | cut -f2)}
  archive=$(tdvp_source_archive_locked_file "$package_dir" "$source_name")
  tar -xf "$archive" -C "$work/source"
  local -a source_roots=()
  mapfile -t source_roots < <(find "$work/source" -mindepth 1 -maxdepth 1 -type d -print)
  [[ ${#source_roots[@]} == 1 ]] || { echo 'source archive must have one root directory' >&2; exit 65; }
  source_root=${source_roots[0]}
  # A writable, disposable dependency projection, never the SDK itself.
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  if [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT/usr" ]]; then
    cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
  fi
  source "$sdk_root/environment-setup.sh"
  sysroot="$work/sysroot"
  export CC="$CC --sysroot=$sysroot" CXX="$CXX --sysroot=$sysroot"
  # Xuantie GCC 14.1.1 has reproducible cfgcleanup ICEs in several older
  # upstreams at -O2/-O3. Preserve the SDK ABI and hardening policy while
  # using its stable -O1 code-generation path for newly built feed payloads.
  export CFLAGS="$CFLAGS -fPIC -fno-shrink-wrap -O1" CXXFLAGS="$CXXFLAGS -fPIC -fno-shrink-wrap -O1"
  export PKG_CONFIG_SYSROOT_DIR="$sysroot"
  export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
  export PKG_CONFIG=$(command -v /usr/bin/pkg-config)
  export LDFLAGS="-Wl,-rpath-link,$sysroot/usr/lib -L$sysroot/usr/lib"
  jobs=${TDVP_JOBS:-$(nproc)}
  cd "$source_root"
  local source_patch
  while IFS= read -r source_patch; do
    patch -p1 <"$package_dir/$source_patch"
  done < <(sed -n "s/^SOURCE_PATCH_[0-9]*_FILE='\([^']*\)'/\1/p" "$package_dir/source.lock")
  local -a options=() make_options=()
  case "$component" in
    tdvp-audacious|tdvp-audacious-plugins)
      cat >"$work/cross.ini" <<EOF
[binaries]
c = ['$sdk_root/bin/riscv64-unknown-linux-gnu-gcc', '--sysroot=$sysroot']
cpp = ['$sdk_root/bin/riscv64-unknown-linux-gnu-g++', '--sysroot=$sysroot']
ar = '$sdk_root/bin/riscv64-unknown-linux-gnu-ar'
strip = '$sdk_root/bin/riscv64-unknown-linux-gnu-strip'
pkgconfig = '/usr/bin/pkg-config'
[host_machine]
system = 'linux'
cpu_family = 'riscv64'
cpu = 'riscv64'
endian = 'little'
[properties]
needs_exe_wrapper = true
sys_root = '$sysroot'
pkg_config_libdir = ['$sysroot/usr/lib/pkgconfig', '$sysroot/usr/share/pkgconfig']
EOF
      # Keep the reviewed feature choices in one place during migration.
      mapfile -t options < <(sed -n 's/^[[:space:]]*\(-D[^[:space:]\\]*\).*/\1/p' \
        "$repo_root/support/audacious-buildroot/$component/$component.mk")
      meson setup "$work/build" --cross-file "$work/cross.ini" --prefix=/usr \
        --libdir=lib --buildtype=release --wrap-mode=nodownload "${options[@]}"
      meson compile -C "$work/build" -j "$jobs"
      DESTDIR="$install_root" meson install -C "$work/build" --no-rebuild
      ;;
    zlib)
      ./configure --prefix=/usr --shared
      make -j"$jobs"
      make DESTDIR="$install_root" install
      ;;
    bzip2)
      # Xuantie GCC 14.1.1 intermittently ICEs in cfgcleanup/ce1 for
      # compress.c at -O2. Keep this component at the stable -O1 level.
      CFLAGS="$CFLAGS -O1"
      make -j"$jobs" -f Makefile-libbz2_so CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS"
      make -j"$jobs" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" bzip2 bzip2recover libbz2.a
      make PREFIX="$install_root/usr" CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS" install
      cp -a libbz2.so* "$install_root/usr/lib/"
      ln -sf libbz2.so.1.0 "$install_root/usr/lib/libbz2.so"
      ;;
    zstd)
      make -j"$jobs" CC="$CC" AR="$AR" CFLAGS="$CFLAGS" HAVE_THREAD=1
      make PREFIX=/usr DESTDIR="$install_root" install
      ;;
    tree)
      make -j"$jobs" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"
      install -Dm0755 tree "$install_root/usr/bin/tree"
      ;;
    dos2unix)
      make -j"$jobs" CC="$CC" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" prefix=/usr ENABLE_NLS=
      make prefix=/usr PREFIX=/usr DESTDIR="$install_root" ENABLE_NLS= install
      ;;
    zip)
      # Info-ZIP 3.0's Unix configure script runs target conftest binaries.
      # Supply the reviewed Linux/glibc cross values directly, so it cannot
      # misdiagnose libc functions after an exec-format failure.
      zip_cflags="-I. -DUNIX -DUIDGID_NOT_16BIT -DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DHAVE_DIRENT_H -DHAVE_TERMIOS_H $CFLAGS"
      make -f unix/Makefile zips CC="$CC" CPP="$CC -E" CFLAGS="$zip_cflags" \
        LFLAGS1='' LFLAGS2="$LDFLAGS -lbz2" LN='ln -s' \
        CC_BZ="$CC" CFLAGS_BZ="$CFLAGS" IZ_BZIP2='' LIB_BZ=''
      make -f unix/Makefile prefix="$install_root/usr" BINDIR="$install_root/usr/bin" \
        MANDIR="$install_root/usr/share/man/man1" install
      ;;
    unzip)
      local debian_archive patch_name
      debian_archive=$(tdvp_source_archive_locked_file "$package_dir" unzip_6.0-27.debian.tar.xz)
      tar -xf "$debian_archive"
      while read -r patch_name _; do
        [[ -z "$patch_name" || "$patch_name" == \#* ]] || patch -p1 <"debian/patches/$patch_name"
      done <debian/patches/series
      make -f unix/Makefile generic CC="$CC" LD="$CC" CF="$CFLAGS -DUNIX" LF="$LDFLAGS"
      install -Dm0755 unzip "$install_root/usr/bin/unzip"
      ;;
    p7zip)
      cp makefile.linux_any_cpu_gcc_4.X makefile.machine
      make -j"$jobs" all2 CC="$CC" CXX="$CXX" CC_SHARED="$CC -fPIC" CXX_SHARED="$CXX -fPIC"
      install -Dm0755 bin/7za "$install_root/usr/bin/7za"
      ;;
    ca-certificates)
      make
      make DESTDIR="$install_root" install
      install -Dm0644 debian/copyright "$install_root/usr/share/licenses/ca-certificates/copyright"
      ;;
    netsurf)
      printf 'override NETSURF_USE_DUKTAPE := YES\noverride NETSURF_USE_WEBP := YES\n' >netsurf/Makefile.config
      mkdir -p "$work/tmpusr"
      export CFLAGS="$CFLAGS -I$work/tmpusr/include"
      export LDFLAGS="$LDFLAGS -L$work/tmpusr/lib"
      make_options=(TARGET=gtk3 BUILD_CC=gcc CC="$CC" AR="$AR" BISON=bison FLEX=flex
        PKG_CONFIG="$PKG_CONFIG" TMP_PREFIX="$work/tmpusr" PREFIX=/usr)
      make -j"$jobs" "${make_options[@]}" build
      make "${make_options[@]}" DESTDIR="$install_root" install
      install -Dm0644 netsurf/COPYING "$install_root/usr/share/doc/tdvp-netsurf/COPYING"
      ;;
    libopenssl)
      ./Configure linux64-riscv64 shared --prefix=/usr --openssldir=/etc/ssl no-tests
      make -j"$jobs"
      make DESTDIR="$install_root" install_sw
      ;;
    *)
      case "$component" in
        vim)
          options+=(--with-tlib=ncursesw --with-features=huge --disable-gui --without-x --disable-nls
            --disable-pythoninterp --disable-python3interp --disable-perlinterp --disable-rubyinterp --disable-luainterp)
          export vim_cv_getcwd_broken=no vim_cv_memmove_handles_overlap=yes vim_cv_stat_ignores_slash=no
          export vim_cv_toupper_broken=no vim_cv_terminfo=yes vim_cv_tgetent=zero vim_cv_bcopy_handles_overlap=no
          export vim_cv_strcpy_handles_overlap=no
          ;;
        libcurl) options+=(--with-openssl --disable-ldap --disable-ldaps --without-libpsl --without-libidn2 --without-librtmp --without-libssh2 --without-nghttp2) ;;
        pcre2) options+=(--enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 --disable-jit) ;;
        ncurses) options+=(--with-shared --without-debug --without-ada --enable-widec --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig --without-cxx-binding) ;;
        libffi) options+=(--disable-multi-os-directory --disable-docs) ;;
        mpdecimal) export LD="$CC" ;;
        sqlite) options+=(--disable-readline --disable-static); CFLAGS="$CFLAGS -O1" ;;
        expat) options+=(--without-docbook --without-tests --without-examples) ;;
        jq) options+=(--disable-docs --with-oniguruma=no) ;;
        pkgconf) options+=(--disable-shared --enable-static) ;;
        libevent) options+=(--disable-samples --disable-libevent-regress) ;;
        wget) options+=(--with-ssl=openssl --without-libpsl --disable-nls) ;;
        rsync) autoreconf -fi; options+=(--disable-xxhash --disable-zstd --disable-lz4) ;;
        openssh) options+=(--without-pam --without-selinux --without-kerberos5 --without-xauth) ;;
        netcat) options+=(--disable-nls) ;;
        file)
          # file's target build consumes a native magic compiler of the same version.
          mkdir "$work/native"
          (cd "$work/native"; env -u CC -u CXX -u AR -u RANLIB -u CFLAGS -u CPPFLAGS -u LDFLAGS \
            "$source_root/configure" --disable-shared; make -j"$jobs")
          make_options+=(FILE_COMPILE="$work/native/src/file")
          options+=(--disable-libseccomp)
          ;;
        xz|tar|gzip|readline|popt|make|patch|diffutils|strace|grep|sed|findutils|gawk|less|htop|nano|ncdu|pv|dialog|tmux|iperf3|lsof) ;;
        *) echo "no published-SDK source build for component: $component" >&2; exit 64 ;;
      esac
      local reviewed_options
      reviewed_options=$(printf '%s\n' "${TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES:-}" | sed -n 's/^[A-Z0-9_]*_CONF_OPTS=//p')
      if [[ -n "$reviewed_options" ]]; then
        IFS=' ' read -r -a options <<<"$reviewed_options"
      fi
      if [[ ! -f configure ]]; then autoreconf -fi; fi
      ./configure --build="$(gcc -dumpmachine)" --host=riscv64-unknown-linux-gnu \
        --prefix=/usr --libdir=/usr/lib --sysconfdir=/etc "${options[@]}"
      make -j"$jobs" "${make_options[@]}"
      make DESTDIR="$install_root" "${make_options[@]}" install
      if [[ "$component" == pkgconf ]]; then
        ln -sf pkgconf "$install_root/usr/bin/pkg-config"
      fi
      ;;
  esac
  # The calling recipe owns its staging projection and package split.
  for license in COPYING LICENSE LICENSE.txt; do
    if [[ -f "$source_root/$license" ]]; then
      install -Dm0644 "$source_root/$license" "$install_root/usr/share/licenses/$component/$license"
    fi
  done
)
