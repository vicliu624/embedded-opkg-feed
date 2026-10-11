#!/usr/bin/env bash
# Native code generators are isolated from the target SDK and cached by source
# identity plus native compiler identity. They never enter a target IPK.
tdvp_prepare_native_cmake_input() (
  set -Eeuo pipefail
  local package_dir=$1 destination=$2 expected=$3
  shift 3
  source "$package_dir/../../support/source-archive-library.sh"
  local key work source_root
  key=$(python3 "$package_dir/../../scripts/native-cmake-cache-key.py" \
    "$package_dir" "$destination" "$expected" "$@")
  [[ ! -L "$destination" ]] || exit 64
  if [[ -f "$destination/.tdvp-source-key" && -f "$destination/$expected" ]]; then
    [[ "$(<"$destination/.tdvp-source-key")" == "$key" ]] || {
      echo "native cache identity differs; retain old output and select a fresh destination: $destination" >&2
      exit 65
    }
    return 0
  fi
  work=$(mktemp -d /tmp/tdvp-native-cmake.XXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work/source" "$destination"
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  env -u CC -u CXX -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS \
    -u CMAKE_TOOLCHAIN_FILE -u PKG_CONFIG_SYSROOT_DIR -u PKG_CONFIG_LIBDIR \
    cmake -S "$source_root" -B "$work/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE= -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DCMAKE_CXX_COMPILER=/usr/bin/g++ -DCMAKE_AR=/usr/bin/ar \
    -DCMAKE_RANLIB=/usr/bin/ranlib -DCMAKE_INSTALL_PREFIX="$destination" \
    -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF -DCMAKE_CXX_STANDARD=17 "$@"
  cmake --build "$work/build" --parallel "${TDVP_JOBS:-4}"
  cmake --install "$work/build"
  [[ -f "$destination/$expected" ]] || exit 66
  printf '%s\n' "$key" >"$destination/.tdvp-source-key"
)
