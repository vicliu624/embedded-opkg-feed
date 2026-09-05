#!/usr/bin/env bash
# Direct, source-locked CPython build and ownership-preserving IPK split for
# TDVP K230.  Buildroot supplies only the reviewed SDK/sysroot identity; this
# helper never enables BR2_PACKAGE_PYTHON3 or copies a Buildroot target root.
set -Eeuo pipefail
IFS=$'\n\t'

TDVP_PYTHON3_VERSION='3.13.3'
TDVP_PYTHON3_ARCHIVE='Python-3.13.3.tar.xz'
TDVP_PYTHON3_ARCHIVE_SHA256='40f868bcbdeb8149a3149580bb9bfd407b3321cd48f0be631af955ac92c0e041'
# Immutable v3.13.3 upstream-tag commit metadata.  CPython otherwise embeds
# the wall-clock compiler date and time in libpython's public build info.
TDVP_PYTHON3_BUILD_INFO_DATE='Apr 08 2025'
TDVP_PYTHON3_BUILD_INFO_TIME='13:54:08'
TDVP_PYTHON3_SOURCE_DATE_EPOCH='1744120448'

tdvp_python3_stage_dir() {
  local stage_root=${TDVP_FEED_STAGING_ROOT:-}
  [[ -n "$stage_root" && -d "$stage_root" && ! -L "$stage_root" ]] || {
    echo 'CPython source build requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 64
  }
  stage_root=$(cd -- "$stage_root" && pwd -P)
  printf '%s\n' "$stage_root/.tdvp-python3-${TDVP_PYTHON3_VERSION}"
}

tdvp_python3_assert_target_elf() {
  local readelf_tool=$1 elf=$2
  "$readelf_tool" -h "$elf" 2>/dev/null | grep -Fq 'Class:                             ELF64' || {
    echo "CPython payload is not an ELF64 object: $elf" >&2
    return 65
  }
  "$readelf_tool" -h "$elf" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
    echo "CPython payload is not a RISC-V ELF: $elf" >&2
    return 66
  }
}

tdvp_python3_for_each_target_elf() {
  local readelf_tool=$1 root=$2 callback=$3
  local file
  while IFS= read -r -d '' file; do
    if "$readelf_tool" -h "$file" 2>/dev/null | grep -Fq 'Class:                             ELF64'; then
      "$callback" "$file"
    fi
  done < <(find "$root/usr" -type f -print0 | LC_ALL=C sort -z)
}

tdvp_python3_assert_payload_elfs() {
  local readelf_tool=$1 root=$2
  local assert_one
  # shellcheck source=elf-runtime-policy.sh
  source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/elf-runtime-policy.sh"
  assert_one() {
    local elf=$1
    tdvp_python3_assert_target_elf "$readelf_tool" "$elf"
    tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$elf"
  }
  tdvp_python3_for_each_target_elf "$readelf_tool" "$root" assert_one
}

tdvp_python3_locked_archive() {
  local package_dir=$1 repo_root verifier cache_root row url file hash ignored archive
  local -a rows=()
  [[ -f "$package_dir/source.lock" && ! -L "$package_dir/source.lock" ]] || {
    echo "CPython package lacks a regular source.lock: $package_dir" >&2
    return 67
  }
  : "${TDVP_SOURCE_CACHE_ROOT:?CPython source build requires TDVP_SOURCE_CACHE_ROOT from build-all.sh}"
  [[ -d "$TDVP_SOURCE_CACHE_ROOT" && ! -L "$TDVP_SOURCE_CACHE_ROOT" ]] || {
    echo "CPython source cache is not a regular directory: $TDVP_SOURCE_CACHE_ROOT" >&2
    return 68
  }
  repo_root=$(cd -- "$package_dir/../.." && pwd -P)
  verifier="$repo_root/scripts/verify-source-lock.sh"
  [[ -f "$verifier" && ! -L "$verifier" ]] || {
    echo "source-lock verifier is missing or unsafe: $verifier" >&2
    return 69
  }
  mapfile -t rows < <(bash "$verifier" --package-dir "$package_dir" --emit-artifacts)
  [[ ${#rows[@]} -eq 1 ]] || {
    echo "CPython build expects exactly one locked source archive: $package_dir" >&2
    return 70
  }
  IFS=$'\t' read -r url file hash ignored <<<"${rows[0]}"
  [[ -n "$url" && -n "$file" && -n "$hash" && -z "$ignored" ]] || {
    echo "could not parse the locked CPython source artifact: $package_dir" >&2
    return 71
  }
  [[ "$file" == "$TDVP_PYTHON3_ARCHIVE" && "$hash" == "$TDVP_PYTHON3_ARCHIVE_SHA256" ]] || {
    echo 'CPython source.lock does not match the reviewed 3.13.3 archive identity' >&2
    return 72
  }
  cache_root=$(cd -- "$TDVP_SOURCE_CACHE_ROOT" && pwd -P)
  archive="$cache_root/sha256/$hash/$file"
  [[ -f "$archive" && ! -L "$archive" ]] || {
    echo "locked CPython archive is absent from source cache: $archive" >&2
    return 73
  }
  [[ "$(sha256sum "$archive" | awk '{print $1}')" == "$hash" ]] || {
    echo "locked CPython archive hash differs in source cache: $archive" >&2
    return 74
  }
  printf '%s\n' "$archive"
}

tdvp_python3_assert_stage_marker() {
  local stage_dir=$1 marker="$stage_dir/.tdvp-python3-source-build"
  [[ -f "$marker" && ! -L "$marker" ]] || {
    echo "CPython source staging has no verified marker: $stage_dir" >&2
    return 75
  }
  grep -Fqx 'format=2' "$marker" &&
    grep -Fqx "version=$TDVP_PYTHON3_VERSION" "$marker" &&
    grep -Fqx "source-sha256=$TDVP_PYTHON3_ARCHIVE_SHA256" "$marker" &&
    grep -Fqx 'build-mode=direct-cross' "$marker" &&
    grep -Fqx "build-info-date=$TDVP_PYTHON3_BUILD_INFO_DATE" "$marker" &&
    grep -Fqx "build-info-time=$TDVP_PYTHON3_BUILD_INFO_TIME" "$marker" &&
    grep -Fqx "source-date-epoch=$TDVP_PYTHON3_SOURCE_DATE_EPOCH" "$marker" &&
    grep -Fqx "source-path=/usr/src/Python-$TDVP_PYTHON3_VERSION" "$marker" &&
    grep -Fqx 'sysconfig-paths=normalized' "$marker" &&
    grep -Fqx 'system-expat=libexpat.so.1' "$marker" &&
    grep -Fqx 'curses-panel=disabled' "$marker" || {
      echo "CPython source staging marker is not the reviewed direct build: $marker" >&2
      return 76
    }
  [[ -f "$stage_dir/usr/lib/libpython3.13.so.1.0" &&
     -d "$stage_dir/usr/lib/python3.13" &&
     -x "$stage_dir/usr/bin/python3.13" ]] || {
    echo "CPython source staging is incomplete: $stage_dir" >&2
    return 77
  }
}

tdvp_python3_require_extension() {
  local dynload=$1 name=$2 found
  shopt -s nullglob
  local -a matches=("$dynload/$name"*.so)
  shopt -u nullglob
  [[ ${#matches[@]} -eq 1 ]] || {
    echo "CPython direct build omitted or duplicated native extension $name" >&2
    return 78
  }
  found=${matches[0]}
  printf '%s\n' "$found"
}

tdvp_python3_assert_runtime_exclusions() {
  local root=$1 stdlib
  stdlib="$root/usr/lib/python3.13"
  [[ ! -e "$root/usr/lib/libpython3.so" ]] || {
    echo 'CPython payload must not publish the generic libpython3.so ABI indirection' >&2
    return 79
  }
  if find "$stdlib" -type f \( \
    -name 'pydoc.py' -o -name 'pydoc.cpython-313*.pyc' -o \
    -name 'turtle.py' -o -name 'turtle.cpython-313*.pyc' \
  \) -print -quit | grep -q .; then
    echo 'CPython runtime retained a deliberately excluded pydoc or turtle module' >&2
    return 80
  fi
}

tdvp_build_python3_source_stage() {
  local package_dir=$1 sdk_root=$2 configured_output=${3:-}
  local output tree sysroot readelf_tool strip_tool host_python archive stage_dir work_root source_root install_root
  local buildinfo_source reproducible_source_root sysconfig_source
  local -a sysconfig_sources=()
  local build_triplet jobs dynload pyexpat extension
  local -a required_extensions=(
    _ssl _hashlib _ctypes _decimal _sqlite3 _bz2 _lzma _curses readline
    pyexpat _elementtree zlib binascii
  )

  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  # shellcheck source=elf-runtime-policy.sh
  source "$package_dir/../../support/elf-runtime-policy.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx 'PYTHON3_VERSION_MAJOR = 3.13' "$tree/package/python3/python3.mk" || {
    echo 'locked Buildroot CPython major version differs from the reviewed source build' >&2
    return 79
  }
  grep -Fqx 'PYTHON3_VERSION = $(PYTHON3_VERSION_MAJOR).3' "$tree/package/python3/python3.mk" || {
    echo 'locked Buildroot CPython patch version differs from the reviewed source build' >&2
    return 80
  }
  grep -Fqx "sha256  $TDVP_PYTHON3_ARCHIVE_SHA256  $TDVP_PYTHON3_ARCHIVE" \
    "$tree/package/python3/python3.hash" || {
    echo 'locked Buildroot CPython archive hash differs from the reviewed source build' >&2
    return 81
  }

  sysroot="$sdk_root/riscv64-buildroot-linux-gnu/sysroot"
  readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
  strip_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-strip"
  host_python="$sdk_root/bin/python3.13"
  for tool in "$readelf_tool" "$strip_tool" "$host_python" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-g++" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ar" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ranlib" \
    "$sdk_root/bin/pkg-config"; do
    [[ -x "$tool" ]] || { echo "matching SDK is missing required CPython build tool: $tool" >&2; return 82; }
  done
  [[ -d "$sysroot" && ! -L "$sysroot" ]] || { echo "matching SDK sysroot is invalid: $sysroot" >&2; return 83; }
  "$host_python" --version | grep -Fq 'Python 3.13.' || {
    echo "matching SDK host Python is not a CPython 3.13 builder: $host_python" >&2
    return 84
  }

  stage_dir=$(tdvp_python3_stage_dir)
  if [[ -e "$stage_dir" || -L "$stage_dir" ]]; then
    [[ -d "$stage_dir" && ! -L "$stage_dir" ]] || {
      echo "refusing to use a non-directory CPython staging path: $stage_dir" >&2
      return 85
    }
    tdvp_python3_assert_stage_marker "$stage_dir"
    return 0
  fi

  archive=$(tdvp_python3_locked_archive "$package_dir")
  jobs=${TDVP_JOBS:-$(nproc)}
  [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "TDVP_JOBS must be a positive integer: $jobs" >&2; return 86; }
  command -v gcc >/dev/null || { echo 'direct CPython cross build requires host gcc for --build identity' >&2; return 87; }
  build_triplet=$(gcc -dumpmachine)
  [[ -n "$build_triplet" ]] || { echo 'could not determine host build triplet for CPython' >&2; return 88; }

  work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-python-build.XXXXXX")
  cleanup_python3_source_build() { rm -rf -- "$work_root"; }
  trap cleanup_python3_source_build RETURN
  tar -xJf "$archive" -C "$work_root"
  source_root="$work_root/Python-$TDVP_PYTHON3_VERSION"
  [[ -d "$source_root" && ! -L "$source_root" ]] || {
    echo "locked CPython archive has an unexpected source directory: $source_root" >&2
    return 89
  }
  # The release source deliberately falls back to __DATE__/__TIME__ in
  # Modules/getbuildinfo.c.  Its value is part of libpython, so use the
  # immutable upstream tag commit time instead of the GitHub runner clock.
  buildinfo_source="$source_root/Modules/getbuildinfo.c"
  [[ -f "$buildinfo_source" && ! -L "$buildinfo_source" ]] || {
    echo "locked CPython source lacks a regular build-info source: $buildinfo_source" >&2
    return 104
  }
  grep -Fqx '#define DATE __DATE__' "$buildinfo_source" &&
    grep -Fqx '#define TIME __TIME__' "$buildinfo_source" || {
      echo 'locked CPython build-info source no longer has the reviewed time fallbacks' >&2
      return 105
    }
  sed -i \
    -e "s|^#define DATE __DATE__$|#define DATE \"$TDVP_PYTHON3_BUILD_INFO_DATE\"|" \
    -e "s|^#define TIME __TIME__$|#define TIME \"$TDVP_PYTHON3_BUILD_INFO_TIME\"|" \
    "$buildinfo_source"
  grep -Fqx "#define DATE \"$TDVP_PYTHON3_BUILD_INFO_DATE\"" "$buildinfo_source" &&
    grep -Fqx "#define TIME \"$TDVP_PYTHON3_BUILD_INFO_TIME\"" "$buildinfo_source" || {
      echo 'could not normalize CPython build-info metadata' >&2
      return 106
    }
  install_root="$work_root/install-root"
  reproducible_source_root="/usr/src/Python-$TDVP_PYTHON3_VERSION"

  (
    cd -- "$source_root"
    export PATH="$sdk_root/bin:$PATH"
    export LD_LIBRARY_PATH="$sdk_root/lib:$sdk_root/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export LC_ALL=C
    export TZ=UTC
    export SOURCE_DATE_EPOCH="$TDVP_PYTHON3_SOURCE_DATE_EPOCH"
    export PYTHONHASHSEED=0
    export CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc --sysroot=$sysroot"
    export CXX="$sdk_root/bin/riscv64-unknown-linux-gnu-g++ --sysroot=$sysroot"
    export AR="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ar"
    export RANLIB="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ranlib"
    export READELF="$readelf_tool"
    export PKG_CONFIG="$sdk_root/bin/pkg-config"
    export PKG_CONFIG_SYSROOT_DIR="$sysroot"
    export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
    export PKG_CONFIG_PATH=''
    export CFLAGS="-ffile-prefix-map=$work_root=$reproducible_source_root -fdebug-prefix-map=$work_root=$reproducible_source_root -fmacro-prefix-map=$work_root=$reproducible_source_root"
    export CPPFLAGS="-I$sysroot/usr/include"
    export LDFLAGS="-L$sysroot/usr/lib -Wl,-rpath-link,$sysroot/usr/lib"
    export ac_cv_buggy_getaddrinfo=no
    export ac_cv_file__dev_ptmx=yes
    export ac_cv_file__dev_ptc=yes
    export ac_cv_working_tzset=yes
    export ac_cv_little_endian_double=yes
    export py_cv_module__uuid=n/a
    export py_cv_module_nis=n/a
    export py_cv_module_ossaudiodev=n/a
    export py_cv_module__curses_panel=n/a
    ./configure \
      --build="$build_triplet" \
      --host=riscv64-unknown-linux-gnu \
      --prefix=/usr \
      --enable-shared \
      --without-static-libpython \
      --without-ensurepip \
      --with-build-python="$host_python" \
      --with-system-expat \
      --with-system-libmpdec \
      --with-openssl="$sysroot/usr" \
      --with-openssl-rpath=no \
      --disable-test-modules
    make -j"$jobs"
    # The generated sysconfig module is installed as a runtime .py file and
    # then compiled to .pyc.  It records abs_srcdir/abs_builddir and would
    # otherwise preserve this mktemp path even when ELF debug paths are mapped.
    mapfile -t sysconfig_sources < <(
      find "$source_root" -maxdepth 3 -type f -name '_sysconfigdata_*.py' -print | LC_ALL=C sort
    )
    [[ ${#sysconfig_sources[@]} -eq 1 ]] || {
      echo "CPython build produced an ambiguous sysconfig-data set: ${#sysconfig_sources[@]}" >&2
      return 107
    }
    for sysconfig_source in "${sysconfig_sources[@]}"; do
      sed -i "s|$work_root|$reproducible_source_root|g" "$sysconfig_source"
      if grep -Fq "$work_root" "$sysconfig_source"; then
        echo "CPython sysconfig still exposes the temporary build root: $sysconfig_source" >&2
        return 108
      fi
    done
    make DESTDIR="$install_root" install
  )

  [[ -x "$install_root/usr/bin/python3.13" &&
     -e "$install_root/usr/lib/libpython3.13.so.1.0" &&
     -d "$install_root/usr/lib/python3.13" ]] || {
    echo 'direct CPython source install omitted the CLI, public library, or standard library' >&2
    return 90
  }
  rm -rf -- "$install_root/usr/include" "$install_root/usr/lib/pkgconfig" "$install_root/usr/share/man"
  rm -rf -- "$install_root/usr/lib/python3.13/ensurepip" \
    "$install_root/usr/lib/python3.13/idlelib" "$install_root/usr/lib/python3.13/tkinter" \
    "$install_root/usr/lib/python3.13/turtledemo" "$install_root/usr/lib/python3.13/pydoc_data" \
    "$install_root/usr/lib/python3.13/config-3.13-riscv64-linux-gnu"
  rm -f -- "$install_root/usr/lib/python3.13/pydoc.py" "$install_root/usr/lib/python3.13/turtle.py"
  rm -f -- "$install_root/usr/lib/python3.13/__pycache__"/pydoc.cpython-313*.pyc \
    "$install_root/usr/lib/python3.13/__pycache__"/turtle.cpython-313*.pyc
  rm -f -- "$install_root/usr/bin"/idle* "$install_root/usr/bin"/pydoc* \
    "$install_root/usr/bin"/python*-config "$install_root/usr/lib/libpython3.so"
  [[ ! -e "$install_root/usr/bin/python" ]] || rm -f -- "$install_root/usr/bin/python"
  ln -s python3 "$install_root/usr/bin/python"

  while IFS= read -r -d '' extension; do
    if "$readelf_tool" -h "$extension" 2>/dev/null | grep -Fq 'Class:                             ELF64'; then
      "$strip_tool" --strip-unneeded "$extension"
    fi
  done < <(find "$install_root/usr" -type f -print0 | LC_ALL=C sort -z)
  tdvp_python3_assert_payload_elfs "$readelf_tool" "$install_root"
  tdvp_python3_assert_runtime_exclusions "$install_root"

  dynload="$install_root/usr/lib/python3.13/lib-dynload"
  [[ -d "$dynload" ]] || { echo 'direct CPython source install omitted lib-dynload' >&2; return 91; }
  for extension in "${required_extensions[@]}"; do
    tdvp_python3_require_extension "$dynload" "$extension" >/dev/null
  done
  pyexpat=$(tdvp_python3_require_extension "$dynload" pyexpat)
  "$readelf_tool" -dW "$pyexpat" | grep -Fq 'Shared library: [libexpat.so.1]' || {
    echo 'CPython pyexpat did not dynamically use the admitted libexpat.so.1 provider' >&2
    return 92
  }
  if find "$dynload" -maxdepth 1 -type f -name '_curses_panel*.so' -print -quit | grep -q .; then
    echo 'CPython build unexpectedly enabled _curses_panel and would require an unadmitted libpanelw provider' >&2
    return 93
  fi
  if find "$install_root/usr" -type f \( -name 'libexpat.a' -o -name 'libexpat.so*' \) -print -quit | grep -q .; then
    echo 'CPython payload must not carry a private Expat library copy' >&2
    return 94
  fi

  mkdir -p -- "$stage_dir"
  cp -a -- "$install_root/usr" "$stage_dir/usr"
  cat >"$stage_dir/.tdvp-python3-source-build" <<EOF
format=2
version=$TDVP_PYTHON3_VERSION
source-sha256=$TDVP_PYTHON3_ARCHIVE_SHA256
build-mode=direct-cross
build-info-date=$TDVP_PYTHON3_BUILD_INFO_DATE
build-info-time=$TDVP_PYTHON3_BUILD_INFO_TIME
source-date-epoch=$TDVP_PYTHON3_SOURCE_DATE_EPOCH
source-path=/usr/src/Python-$TDVP_PYTHON3_VERSION
sysconfig-paths=normalized
system-expat=libexpat.so.1
curses-panel=disabled
EOF
  tdvp_python3_assert_stage_marker "$stage_dir"
}

tdvp_python3_replace_payload_root() {
  local package_dir=$1 root_link payload_dir= previous_payload= temporary_prefix
  root_link="$package_dir/root"
  temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."
  if [[ -e "$root_link" || -L "$root_link" ]]; then
    if [[ -L "$root_link" ]]; then
      previous_payload=$(readlink -f -- "$root_link" 2>/dev/null || true)
      if [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]]; then
        rm -f -- "$root_link"
        rm -rf -- "$previous_payload"
      else
        echo "refusing to replace a payload root not generated by TDVP: $root_link" >&2
        return 95
      fi
    else
      echo "refusing to replace a non-symlink payload root: $root_link" >&2
      return 96
    fi
  fi
  payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
  chmod 0755 -- "$payload_dir"
  ln -s -- "$payload_dir" "$root_link"
  printf '%s\n' "$payload_dir"
}

tdvp_prepare_python_payload() {
  local package_dir=$1 split=$2 sdk_root=$3
  local stage_dir source_root payload_dir root_link readelf_tool payload_ready=0
  stage_dir=$(tdvp_python3_stage_dir)
  tdvp_python3_assert_stage_marker "$stage_dir"
  source_root="$stage_dir/usr"
  readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
  [[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; return 97; }
  root_link="$package_dir/root"
  payload_dir=$(tdvp_python3_replace_payload_root "$package_dir")
  cleanup_python3_payload() {
    local rc=$?
    if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
      rm -rf -- "$payload_dir"
      if [[ -L "$root_link" && "$(readlink -f -- "$root_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
        rm -f -- "$root_link"
      fi
    fi
    return "$rc"
  }
  trap cleanup_python3_payload RETURN

  case "$split" in
    libpython)
      mkdir -p -- "$payload_dir/usr/lib"
      [[ -f "$source_root/lib/libpython3.13.so.1.0" ]] || {
        echo 'CPython source staging omitted libpython3.13 SONAME' >&2
        return 98
      }
      cp -a -- "$source_root/lib/libpython3.13.so"* "$payload_dir/usr/lib/"
      ;;
    runtime)
      mkdir -p -- "$payload_dir/usr/lib"
      cp -a -- "$source_root/lib/python3.13" "$payload_dir/usr/lib/python3.13"
      [[ ! -e "$payload_dir/usr/lib/libpython3.13.so.1.0" ]] || {
        echo 'python3-runtime must not duplicate the public libpython ABI' >&2
        return 99
      }
      ;;
    cli)
      mkdir -p -- "$payload_dir/usr/bin"
      local bin
      for bin in python python3 python3.13; do
        [[ -e "$source_root/bin/$bin" || -L "$source_root/bin/$bin" ]] || {
          echo "CPython source staging omitted command frontend: $bin" >&2
          return 100
        }
        cp -a -- "$source_root/bin/$bin" "$payload_dir/usr/bin/"
      done
      ;;
    *)
      echo "unsupported CPython payload split: $split" >&2
      return 101
      ;;
  esac
  tdvp_python3_assert_payload_elfs "$readelf_tool" "$payload_dir"
  if [[ "$split" == runtime ]]; then
    local dynload pyexpat
    dynload="$payload_dir/usr/lib/python3.13/lib-dynload"
    pyexpat=$(tdvp_python3_require_extension "$dynload" pyexpat)
    "$readelf_tool" -dW "$pyexpat" | grep -Fq 'Shared library: [libexpat.so.1]' || {
      echo 'python3-runtime pyexpat lost its admitted libexpat.so.1 linkage' >&2
      return 102
    }
    if find "$dynload" -maxdepth 1 -type f -name '_curses_panel*.so' -print -quit | grep -q .; then
      echo 'python3-runtime must not publish _curses_panel without a libpanelw provider' >&2
      return 103
    fi
    tdvp_python3_assert_runtime_exclusions "$payload_dir"
  fi
  payload_ready=1
  echo "$(basename "$package_dir") CPython $split payload ready: $payload_dir"
}
