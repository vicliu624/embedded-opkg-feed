#!/usr/bin/env bash
# Source-build an individual component with the released application SDK.
# The SDK and image remain read-only; build dependencies live in private staging.
set -Eeuo pipefail

tdvp_sdk_install() (
  set -Eeuo pipefail
  local package_dir=$1 sdk_root=$2 component=$3 install_root=$4
  local repo_root work source_root sysroot jobs archive
  repo_root=$(cd -- "$package_dir/../.." && pwd)
  source "$repo_root/scripts/feed-platform.sh"
  tdvp_assert_package_host_dependencies "$package_dir"
  source "$repo_root/support/source-archive-library.sh"
  work=$(mktemp -d /tmp/tdvp-sdk-build.XXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work/source" "$work/sysroot" "$install_root"
  local source_name
  source_name=${TDVP_SDK_SOURCE_ARCHIVE:-$(bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" --emit-artifacts | sed -n '1p' | cut -f2)}
  archive=$(tdvp_source_archive_locked_file "$package_dir" "$source_name")
  if [[ "$source_name" == *.tar.lz ]]; then
    # GNU Make's locked .tar.lz requires the separately locked host lzip.
    # Build it outside the target sysroot; never depend on an ambient binary.
    local lzip_archive
    lzip_archive=$(tdvp_source_archive_locked_file "$package_dir" lzip-1.25.tar.gz)
    mkdir -p "$work/host-source" "$work/host-tools"
    tar -xzf "$lzip_archive" -C "$work/host-source"
    (
      cd "$work/host-source/lzip-1.25"
      env -u CC -u CXX -u AR -u RANLIB -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
        ./configure --prefix="$work/host-tools"
      make -j"${TDVP_JOBS:-$(nproc)}"
      make install
    )
    export PATH="$work/host-tools/bin:$PATH"
  fi
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
      command -v glib-compile-resources >/dev/null || {
        echo 'Audacious source build requires host glib-compile-resources' >&2
        exit 66
      }
      cat >"$work/cross.ini" <<EOF
[binaries]
c = ['$sdk_root/bin/riscv64-unknown-linux-gnu-gcc', '--sysroot=$sysroot']
cpp = ['$sdk_root/bin/riscv64-unknown-linux-gnu-g++', '--sysroot=$sysroot']
ar = '$sdk_root/bin/riscv64-unknown-linux-gnu-ar'
strip = '$sdk_root/bin/riscv64-unknown-linux-gnu-strip'
pkg-config = '/usr/bin/pkg-config'
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
        CC_BZ="$CC" CFLAGS_BZ="$CFLAGS" IZ_BZIP2='' LIB_BZ='' \
        OCRCU8='crc32_.o' OCRCTB=''
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
      # Like zip, UnZip's generic configure executes target conftest
      # programs. Supply the reviewed Linux/glibc feature set directly.
      unzip_cf="-I. -Ibzip2 -DUNIX -DUNICODE_SUPPORT -DUTF8_MAYBE_NATIVE -D_MBCS -DHAVE_DIRENT_H -DHAVE_TERMIOS_H $CFLAGS"
      make -f unix/Makefile unzips CC="$CC" LD="$CC" CF="$unzip_cf" \
        LF="-o unzip" LF2="$LDFLAGS" \
        FL="-o funzip" FL2="$LDFLAGS" \
        SL="-o unzipsfx" SL2="$LDFLAGS"
      make -f unix/Makefile prefix="$install_root/usr" BINDIR="$install_root/usr/bin" \
        MANDIR="$install_root/usr/share/man/man1" install
      ;;
    p7zip)
      cp makefile.linux_any_cpu_gcc_4.X makefile.machine
      # p7zip concatenates CC/CXX into several intermediate command lines.
      # They must be compiler paths, while sysroot and hardening settings go
      # through the Buildroot-supported ALLFLAGS variables.
      p7_cc="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc"
      p7_cxx="$sdk_root/bin/riscv64-unknown-linux-gnu-g++"
      p7_flags="--sysroot=$sysroot $CFLAGS"
      make -j"$jobs" 7za CC="$p7_cc" CXX="$p7_cxx" \
        ALLFLAGS_C="$p7_flags" ALLFLAGS_CPP="$p7_flags" LDFLAGS="$LDFLAGS"
      install -Dm0755 bin/7za "$install_root/usr/bin/7za"
      ;;
    ca-certificates)
      make
      mkdir -p \
        "$install_root/etc" \
        "$install_root/usr/share/ca-certificates"
      make DESTDIR="$install_root" install
      install -Dm0644 debian/copyright \
        "$install_root/usr/share/licenses/ca-certificates/copyright"
      ;;
    webp)
      options+=(--disable-sdl --disable-gl --disable-tiff --disable-gif
        --enable-libwebpdemux --enable-libwebpmux)
      ./configure --build="$(gcc -dumpmachine)" --host=riscv64-unknown-linux-gnu \
        --prefix=/usr --libdir=/usr/lib --with-sysroot="$sysroot" \
        --disable-static --enable-shared "${options[@]}"
      # Target libraries use the loader's standard /usr/lib search path.
      # Avoid install-time hardcoding/relinking against the build host.
      sed -i -e 's/^hardcode_into_libs=yes$/hardcode_into_libs=no/' \
        -e 's/^hardcode_action=relink$/hardcode_action=immediate/' \
        -e 's/^hardcode_automatic=no$/hardcode_automatic=yes/' libtool
      make -j"$jobs"
      make DESTDIR="$install_root" install
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
    libubootenv)
      printf '%s\n' "include(\"$sdk_root/toolchain.cmake\")" \
        "set(CMAKE_SYSROOT \"$sysroot\")" \
        "set(CMAKE_FIND_ROOT_PATH \"$sysroot\")" \
        'set(PKG_CONFIG_EXECUTABLE "/usr/bin/pkg-config" CACHE FILEPATH "Private target pkg-config" FORCE)' \
        >"$work/private-toolchain.cmake"
      cmake -S . -B "$work/build" -DCMAKE_TOOLCHAIN_FILE="$work/private-toolchain.cmake" \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_C_FLAGS="$CFLAGS" \
        -DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS"
      cmake --build "$work/build" -j"$jobs"
      DESTDIR="$install_root" cmake --install "$work/build"
      ;;
    mxml)
      ./configure --build="$(gcc -dumpmachine)" --host=riscv64-unknown-linux-gnu \
        --prefix=/usr --libdir=/usr/lib --enable-shared --disable-static
      make -j"$jobs"
      make DSTROOT="$install_root" install
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
        dialog) options+=(--with-ncursesw) ;;
        libcurl) options+=(--with-openssl --disable-ldap --disable-ldaps --without-libpsl --without-libidn2 --without-librtmp --without-libssh2 --without-nghttp2) ;;
        pcre2) options+=(--enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 --disable-jit) ;;
        ncurses) options+=(--with-shared --without-debug --without-ada --enable-widec --enable-pc-files --with-pkg-config-libdir=/usr/lib/pkgconfig --without-cxx-binding --with-termlib --enable-overwrite) ;;
        libffi) options+=(--disable-multi-os-directory --disable-docs) ;;
        mpdecimal) export LD="$CC" ;;
        sqlite) options+=(--disable-readline --disable-static); CFLAGS="$CFLAGS -O1" ;;
        expat) options+=(--without-docbook --without-tests --without-examples) ;;
        libyaml) options+=(--enable-shared --disable-static) ;;
        libmicrohttpd) options+=(--enable-shared --disable-static --disable-curl --disable-examples --disable-https --with-threads=auto) ;;
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
        xz|tar|gzip|readline|popt|make|patch|diffutils|strace|grep|sed|findutils|gawk|less|htop|nano|ncdu|pv|dialog|tmux|iperf3|lsof|which) ;;
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
  for license in COPYING COPYING.txt COPYING.LESSER LICENSE LICENSE.txt LICENCE LICENCE.txt COPYRIGHT NOTICE PATENTS \
    License COPYRIGHT.txt COPYING.0BSD COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 docs/COPYING; do
    if [[ -f "$source_root/$license" ]]; then
      install -Dm0644 "$source_root/$license" "$install_root/usr/share/licenses/$component/$license"
    fi
  done
)
