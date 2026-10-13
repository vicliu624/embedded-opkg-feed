#!/usr/bin/env bash
# One locked source build, one runtime payload, reusable development projection.
tdvp_build_cmake_source_library() (
  set -Eeuo pipefail
  local package_dir=$1 sdk_root=$2 library_glob=$3
  shift 3
  [[ -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 64
  source "$package_dir/../../scripts/feed-platform.sh"
  tdvp_assert_package_host_dependencies "$package_dir"
  source "$package_dir/../../support/source-archive-library.sh"
  source "$package_dir/../../support/elf-runtime-policy.sh"
  [[ -f "$sdk_root/tdvp-sdk-manifest.json" ]] || exit 65
  local work source_root cmake_source_root sysroot install_root payload_dir readelf_tool strip_tool
  work=$(mktemp -d /tmp/tdvp-cmake-source.XXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work/source" "$work/sysroot"
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  if [[ -d "$package_dir/patches" ]]; then
    local source_patch
    local -a source_patches=()
    shopt -s nullglob
    source_patches=("$package_dir/patches/"*.patch)
    shopt -u nullglob
    for source_patch in "${source_patches[@]}"; do
      patch --directory="$source_root" -p1 --fuzz=0 --forward --dry-run < "$source_patch"
      patch --directory="$source_root" -p1 --fuzz=0 --forward < "$source_patch"
    done
  fi
  cmake_source_root="$source_root"
  if [[ -n ${PACKAGE_CMAKE_SUBDIR:-} ]]; then
    [[ "$PACKAGE_CMAKE_SUBDIR" =~ ^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$ ]] || exit 69
    cmake_source_root=$(realpath -e -- "$source_root/$PACKAGE_CMAKE_SUBDIR")
    [[ "$cmake_source_root" == "$source_root/"* && -d "$cmake_source_root" ]] || exit 69
  fi
  [[ -f "$cmake_source_root/CMakeLists.txt" ]] || exit 70
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  if [[ -d "$TDVP_FEED_STAGING_ROOT/usr" ]]; then
    cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
  fi
  source "$sdk_root/environment-setup.sh"
  sysroot="$work/sysroot"
  install_root="$work/install"
  readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
  strip_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-strip"
  export PKG_CONFIG_SYSROOT_DIR="$sysroot"
  export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
  export PKG_CONFIG_PATH=''
  export PKG_CONFIG=/usr/bin/pkg-config
  # environment-setup exports the application toolchain file, which fixes
  # its sysroot to the immutable SDK and hides feed-only development inputs.
  unset CMAKE_TOOLCHAIN_FILE
  local source_path_flags=''
  if [[ ${PACKAGE_REPRODUCIBLE_SOURCE_PATHS:-0} == 1 ]]; then
    [[ "$PACKAGE" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || exit 69
    source_path_flags="-ffile-prefix-map=$work=/usr/src/tdvp/$PACKAGE"
  fi
  cmake -S "$cmake_source_root" -B "$work/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE= -DPKG_CONFIG_EXECUTABLE=/usr/bin/pkg-config \
    -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
    -DCMAKE_SYSROOT="$sysroot" -DCMAKE_FIND_ROOT_PATH="$sysroot" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DCMAKE_C_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
    -DCMAKE_CXX_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-g++" \
    -DCMAKE_C_FLAGS="$CFLAGS -fPIC -O1 $source_path_flags" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS -fPIC -O1 $source_path_flags" \
    -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath-link,$sysroot/usr/lib" \
    -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$sysroot/usr/lib" \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE= \
    -DCMAKE_CXX_FLAGS_RELEASE= -DCMAKE_SKIP_RPATH=ON \
    -DBUILD_SHARED_LIBS=ON "$@"
  if [[ "$library_glob" != '@development' ]]; then
  grep -Fq -- "--sysroot=$sysroot" "$work/build/CMakeFiles/rules.ninja" || {
    echo 'CMake ignored the private target dependency sysroot' >&2
    exit 67
  }
  fi
  cmake --build "$work/build" --parallel "${TDVP_JOBS:-4}"
  DESTDIR="$install_root" cmake --install "$work/build"
  python3 "$package_dir/../../support/normalize-pkgconfig-build-paths.py" "$install_root" \
    --sysroot "$sdk_root/sysroot" --sysroot "$sysroot"
  payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
  if [[ "$library_glob" == '@development' ]]; then
    [[ -d "$install_root/usr/include" ]] || exit 66
    cp -a "$install_root/usr" "$payload_dir/usr"
  else
  compgen -G "$install_root/usr/lib/$library_glob" >/dev/null || exit 66
  mkdir -p "$payload_dir/usr/lib"
  cp -a "$install_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
  tdvp_assert_direct_archive_elfs "$readelf_tool" "$strip_tool" "$payload_dir"
  fi
  mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
  local -a license_args=() license_files=()
  local license_file
  IFS=' ' read -r -a license_files <<< "${PACKAGE_LICENSE_FILES:-}"
  for license_file in "${license_files[@]}"; do license_args+=(--license-file "$license_file"); done
  python3 "$package_dir/../../support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir" "${license_args[@]}"
  cp -a "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
  mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
  cp -a "$payload_dir/usr/share/licenses/$PACKAGE" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
  printf '%s\n' "$PACKAGE CMake source payload ready: $payload_dir"
)
