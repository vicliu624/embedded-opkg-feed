#!/usr/bin/env bash
# Build one reusable public SONAME directly from an immutable source artifact.
#
# This helper never takes a file from a Buildroot target installation. The
# package-local source.lock is verified into the content-addressed cache first;
# the matching K230 SDK supplies only the ABI/sysroot, and the package publishes
# just its own SONAME family.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_prepare_generated_payload_root() {
  local package_dir=$1
  local root_link="$package_dir/root" previous_payload= payload_dir
  local temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."

  if [[ -e "$root_link" || -L "$root_link" ]]; then
    [[ -L "$root_link" ]] || {
      echo "refusing to replace non-generated payload root: $root_link" >&2
      return 64
    }
    previous_payload=$(readlink -f -- "$root_link" 2>/dev/null || true)
    [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" && ! -L "$previous_payload" ]] || {
      echo "refusing to replace unexpected payload target: $previous_payload" >&2
      return 65
    }
    rm -f -- "$root_link"
    rm -rf -- "$previous_payload"
  fi

  payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
  chmod 0755 -- "$payload_dir"
  ln -s -- "$payload_dir" "$root_link"
  printf '%s\n' "$payload_dir"
}

tdvp_source_archive_locked_file() {
  local package_dir=$1 requested_filename=${2:-}
  local repo_root cache_root artifact url filename expected_sha256 archive selected_artifact=
  local -a cache_arguments=() artifacts=()

  repo_root=$(cd -- "$package_dir/../.." && pwd)
  cache_root=${TDVP_SOURCE_CACHE_ROOT:-"$repo_root/.tdvp-source-cache"}
  if [[ -e "$cache_root" || -L "$cache_root" ]]; then
    [[ -d "$cache_root" && ! -L "$cache_root" ]] || {
      echo "source cache is not a regular directory: $cache_root" >&2
      return 66
    }
  else
    mkdir -p -- "$cache_root"
  fi
  mapfile -t artifacts < <(bash "$repo_root/scripts/verify-source-lock.sh" \
    --package-dir "$package_dir" --emit-artifacts)
  if [[ -z "$requested_filename" ]]; then
    [[ ${#artifacts[@]} -eq 1 ]] || {
      echo "locked archive selection is ambiguous; name the required artifact: $package_dir" >&2
      return 67
    }
    selected_artifact=${artifacts[0]}
  else
    [[ "$requested_filename" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
      echo "locked archive selection has an unsafe filename: $requested_filename" >&2
      return 67
    }
    for artifact in "${artifacts[@]}"; do
      IFS=$'\t' read -r url filename expected_sha256 <<<"$artifact"
      if [[ "$filename" == "$requested_filename" ]]; then
        [[ -z "$selected_artifact" ]] || {
          echo "locked archive selection is not unique: $requested_filename" >&2
          return 67
        }
        selected_artifact=$artifact
      fi
    done
    [[ -n "$selected_artifact" ]] || {
      echo "locked archive selection is absent: $requested_filename" >&2
      return 67
    }
  fi
  artifact=$selected_artifact
  IFS=$'\t' read -r url filename expected_sha256 <<<"$artifact"
  [[ "$url" == https://* && "$filename" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ && \
     "$expected_sha256" =~ ^[0-9a-f]{64}$ ]] || {
    echo "invalid locked source artifact for $package_dir" >&2
    return 68
  }
  archive="$cache_root/sha256/$expected_sha256/$filename"
  if [[ ! -f "$archive" || -L "$archive" ]]; then
    cache_arguments=(--cache "$cache_root" --package-dir "$package_dir")
    [[ "${TDVP_SOURCE_CACHE_OFFLINE:-0}" != 1 ]] || cache_arguments+=(--offline)
    bash "$repo_root/scripts/fetch-source-cache.sh" "${cache_arguments[@]}"
  fi
  [[ -f "$archive" && ! -L "$archive" ]] || {
    echo "locked source archive is absent from source cache: $archive" >&2
    return 69
  }
  [[ "$(sha256sum "$archive" | awk '{print $1}')" == "$expected_sha256" ]] || {
    echo "locked source archive hash differs in source cache: $archive" >&2
    return 70
  }
  printf '%s\n' "$archive"
}

# Extract exactly one reviewed source-tree root from a source.lock artifact.
# Callers supply and clean the temporary destination, which keeps a release
# build independent from an adjacent Git checkout and prevents a source hook
# from obtaining a mutable worktree behind the cache policy.
tdvp_unpack_locked_source_archive() {
  local package_dir=$1 destination=$2 archive top_level source_root
  local -a top_levels=()

  [[ -d "$destination" && ! -L "$destination" ]] || {
    echo "locked source extraction destination is not a regular directory: $destination" >&2
    return 71
  }
  archive=$(tdvp_source_archive_locked_file "$package_dir")
  mapfile -t top_levels < <(tar -tf "$archive" | awk -F/ 'NF > 1 && $1 != "." && $1 != ".." { print $1 }' | LC_ALL=C sort -u)
  [[ ${#top_levels[@]} -eq 1 ]] || {
    echo "locked source archive must contain exactly one top-level tree: $archive" >&2
    return 72
  }
  top_level=${top_levels[0]}
  [[ "$top_level" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
    echo "locked source archive has an unsafe top-level tree: $top_level" >&2
    return 72
  }
  tar -xf "$archive" -C "$destination"
  source_root="$destination/$top_level"
  [[ -d "$source_root" && ! -L "$source_root" ]] || {
    echo "locked source archive did not extract its expected source tree: $source_root" >&2
    return 73
  }
  printf '%s\n' "$source_root"
}

tdvp_assert_direct_archive_elfs() {
  local readelf_tool=$1 strip_tool=$2 payload_dir=$3 elf
  while IFS= read -r -d '' elf; do
    "$readelf_tool" -h "$elf" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
      echo "direct archive library emitted a non-RISC-V ELF: $elf" >&2
      return 71
    }
    "$strip_tool" --strip-unneeded "$elf"
    tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$elf"
  done < <(find "$payload_dir/usr/lib" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)
}

tdvp_build_direct_archive_library() {
  local package_dir=$1 sdk_root=$2 configured_output=$3 source_directory=$4 library_glob=$5
  shift 5
  [[ ${1:-} == -- ]] || {
    echo 'direct archive library requires -- before configure options' >&2
    return 72
  }
  shift
  local -a configure_options=("$@")
  local output sysroot readelf_tool strip_tool archive work_root source_root install_root
  local stage_root payload_dir target_triplet build_triplet jobs

  [[ -n "${TDVP_FEED_STAGING_ROOT:-}" && -d "$TDVP_FEED_STAGING_ROOT" && ! -L "$TDVP_FEED_STAGING_ROOT" ]] || {
    echo 'direct archive library requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
    return 73
  }
  # shellcheck source=../scripts/tdvp-k230-sdk.sh
  source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  # shellcheck source=elf-runtime-policy.sh
  source "$package_dir/../../support/elf-runtime-policy.sh"
  tdvp_require_k230_sdk "$sdk_root"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  [[ -f "$output/.config" ]] || {
    echo "matching Buildroot output has no configuration: $output" >&2
    return 74
  }
  sysroot=$TDVP_K230_SYSROOT
  readelf_tool=$TDVP_K230_READELF
  strip_tool=$TDVP_K230_STRIP
  for tool in tar make gcc "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-g++" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ar" \
    "$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ranlib" \
    "$readelf_tool" "$strip_tool"; do
    [[ -x "$(command -v "$tool" 2>/dev/null || printf '%s' "$tool")" ]] || {
      echo "direct archive library build is missing tool: $tool" >&2
      return 75
    }
  done
  [[ -d "$sysroot" && ! -L "$sysroot" ]] || {
    echo "matching K230 sysroot is invalid: $sysroot" >&2
    return 76
  }

  archive=$(tdvp_source_archive_locked_file "$package_dir")
  jobs=${TDVP_JOBS:-$(nproc)}
  [[ "$jobs" =~ ^[1-9][0-9]*$ ]] || { echo "TDVP_JOBS must be a positive integer: $jobs" >&2; return 77; }
  build_triplet=$(gcc -dumpmachine)
  target_triplet=$("$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" -dumpmachine)
  [[ -n "$build_triplet" && -n "$target_triplet" ]] || {
    echo 'could not determine direct archive library build or target triplet' >&2
    return 78
  }

  work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-source-library-build.XXXXXX")
  cleanup_direct_archive_library() {
    local rc=$?
    rm -rf -- "$work_root"
    return "$rc"
  }
  trap cleanup_direct_archive_library RETURN
  tar -xf "$archive" -C "$work_root"
  source_root="$work_root/$source_directory"
  [[ -d "$source_root" && ! -L "$source_root" && -x "$source_root/configure" ]] || {
    echo "locked source archive has no expected autoconf source root: $source_root" >&2
    return 79
  }
  install_root="$work_root/install-root"

  (
    cd -- "$source_root"
    export PATH="$sdk_root/bin:$PATH"
    export CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc --sysroot=$sysroot"
    export CXX="$sdk_root/bin/riscv64-unknown-linux-gnu-g++ --sysroot=$sysroot"
    export AR="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ar"
    export RANLIB="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc-ranlib"
    export READELF="$readelf_tool"
    export STRIP="$strip_tool"
    export PKG_CONFIG="$sdk_root/bin/pkg-config"
    export PKG_CONFIG_SYSROOT_DIR="$sysroot"
    export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
    export PKG_CONFIG_PATH=''
    export CPPFLAGS="-I$sysroot/usr/include"
    export CFLAGS='-O2 -pipe -fPIC'
    export CXXFLAGS='-O2 -pipe -fPIC'
    export LDFLAGS="-L$sysroot/usr/lib -Wl,-rpath-link,$sysroot/usr/lib"
    ./configure \
      --build="$build_triplet" \
      --host="$target_triplet" \
      --prefix=/usr \
      --enable-shared \
      --disable-static \
      "${configure_options[@]}"
    make -j"$jobs"
    make DESTDIR="$install_root" install
  )

  compgen -G "$install_root/usr/lib/$library_glob" >/dev/null || {
    echo "direct source install omitted $library_glob: $package_dir" >&2
    return 80
  }
  stage_root=$TDVP_FEED_STAGING_ROOT
  mkdir -p -- "$stage_root/usr"
  cp -a -- "$install_root/usr/." "$stage_root/usr/"
  cat >"$stage_root/.tdvp-direct-source-${PACKAGE}" <<EOF
format=1
package=$PACKAGE
version=$VERSION
source-archive=$(basename -- "$archive")
build-mode=direct-cross
EOF

  payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
  mkdir -p -- "$payload_dir/usr/lib"
  cp -a -- "$install_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
  tdvp_assert_direct_archive_elfs "$readelf_tool" "$strip_tool" "$payload_dir"
  echo "$(basename -- "$package_dir") direct-source payload ready: $payload_dir"
}
