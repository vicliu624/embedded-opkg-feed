#!/usr/bin/env bash
# Common cross-build contract for TDVP K230 feed recipes.  The firmware SDK is
# an input, never a package payload; TDVP_FEED_STAGING_ROOT is the temporary
# development sysroot shared only inside one feed-release build.
set -Eeuo pipefail

tdvp_require_k230_sdk() {
  local sdk_root=$1
  [[ -n "$sdk_root" && -d "$sdk_root" ]] || {
    echo 'TDVP K230 feed build requires --sdk-root <matching-buildroot-output/host>' >&2
    return 64
  }
  TDVP_K230_SDK_ROOT=$(cd -- "$sdk_root" && pwd)
  TDVP_K230_TOOLCHAIN_FILE=${TDVP_K230_TOOLCHAIN_FILE:-}
  if [[ -z "$TDVP_K230_TOOLCHAIN_FILE" ]]; then
    for candidate in \
      "$TDVP_K230_SDK_ROOT/share/buildroot/toolchainfile.cmake" \
      "$TDVP_K230_SDK_ROOT/toolchainfile.cmake"; do
      if [[ -f "$candidate" ]]; then
        TDVP_K230_TOOLCHAIN_FILE=$candidate
        break
      fi
    done
  fi
  [[ -n "$TDVP_K230_TOOLCHAIN_FILE" && -f "$TDVP_K230_TOOLCHAIN_FILE" ]] || {
    echo 'could not find the Buildroot CMake toolchain file' >&2
    return 65
  }
  TDVP_K230_HOST_DIR=$(cd -- "$(dirname -- "$TDVP_K230_TOOLCHAIN_FILE")/../.." && pwd)
  TDVP_K230_SYSROOT=$(find "$TDVP_K230_HOST_DIR" -type d -name sysroot -print -quit)
  [[ -n "$TDVP_K230_SYSROOT" && -d "$TDVP_K230_SYSROOT" ]] || {
    echo 'could not find the target sysroot beside the Buildroot toolchain' >&2
    return 66
  }
  TDVP_K230_CMAKE=${TDVP_K230_CMAKE:-"$TDVP_K230_HOST_DIR/bin/cmake"}
  TDVP_K230_NINJA=${TDVP_K230_NINJA:-"$TDVP_K230_HOST_DIR/bin/ninja"}
  TDVP_K230_STRIP=${TDVP_K230_STRIP:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-strip"}
  TDVP_K230_READELF=${TDVP_K230_READELF:-"$TDVP_K230_HOST_DIR/bin/riscv64-unknown-linux-gnu-readelf"}
  for tool in "$TDVP_K230_CMAKE" "$TDVP_K230_NINJA" "$TDVP_K230_STRIP" "$TDVP_K230_READELF"; do
    [[ -x "$tool" ]] || { echo "missing executable in matching K230 SDK: $tool" >&2; return 67; }
  done
  export TDVP_K230_SDK_ROOT TDVP_K230_TOOLCHAIN_FILE TDVP_K230_HOST_DIR \
    TDVP_K230_SYSROOT TDVP_K230_CMAKE TDVP_K230_NINJA TDVP_K230_STRIP TDVP_K230_READELF
}

tdvp_require_wayland_sdk_overlay() {
  local overlay=${TDVP_K230_WAYLAND_SDK_OVERLAY:-}
  [[ -n "$overlay" && -d "$overlay" ]] || {
    echo 'set TDVP_K230_WAYLAND_SDK_OVERLAY to the matching firmware Wayland development overlay' >&2
    return 68
  }
  overlay=$(cd -- "$overlay" && pwd)
  for required in \
    include/wayland-client.h \
    include/xkbcommon/xkbcommon.h \
    include/EGL/egl.h \
    include/pulse/pulseaudio.h \
    include/alsa/asoundlib.h \
    lib/pkgconfig/wayland-client.pc \
    lib/pkgconfig/xkbcommon.pc \
    lib/pkgconfig/libpulse.pc \
    lib/libffi.so lib/libpulse.so lib/libasound.so; do
    [[ -e "$overlay/$required" ]] || {
      echo "invalid TDVP_K230_WAYLAND_SDK_OVERLAY: missing $required" >&2
      return 69
    }
  done
  # Freetype and zlib are ordinary Buildroot sysroot development inputs, not
  # part of this firmware-specific Wayland/Pulse/ALSA bridge. Requiring stale
  # duplicate copies here prevents a correctly matched SDK from building a
  # leaf package while adding no ABI protection; the toolchain file already
  # confines their lookup to TDVP_K230_SYSROOT.
  TDVP_K230_WAYLAND_SDK_OVERLAY=$overlay
  export TDVP_K230_WAYLAND_SDK_OVERLAY
}

tdvp_prepare_pkg_config() {
  local overlay=$TDVP_K230_WAYLAND_SDK_OVERLAY
  local staging=${TDVP_FEED_STAGING_ROOT:-}
  [[ -n "$staging" && -d "$staging" ]] || {
    echo 'TDVP_FEED_STAGING_ROOT is missing; use scripts/build-all.sh' >&2
    return 70
  }
  export PKG_CONFIG_SYSROOT_DIR="$TDVP_K230_SYSROOT"
  export PKG_CONFIG_LIBDIR="$staging/usr/lib/pkgconfig:$staging/usr/share/pkgconfig:$overlay/lib/pkgconfig:$TDVP_K230_SYSROOT/usr/lib/pkgconfig:$TDVP_K230_SYSROOT/usr/share/pkgconfig"
  export PKG_CONFIG_PATH=''
  export PKG_CONFIG_ALLOW_SYSTEM_CFLAGS=1
  export PKG_CONFIG_ALLOW_SYSTEM_LIBS=1
}

tdvp_verify_git_source() {
  local source_root=$1
  local expected_origin=$2
  local expected_revision=$3
  source_root=$(cd -- "$source_root" && pwd)
  command -v git >/dev/null || { echo 'git is required to verify a package source' >&2; return 71; }
  [[ "$(git -C "$source_root" rev-parse --show-toplevel 2>/dev/null)" == "$source_root" ]] || {
    echo "source path is not a Git checkout root: $source_root" >&2
    return 72
  }
  local origin
  origin=$(git -C "$source_root" config --get remote.origin.url || true)
  # Git accepts several spellings for the same GitHub remote.  Source locks
  # pin the repository identity and commit, not an incidental trailing .git
  # suffix or SSH/HTTPS transport choice.
  local normalized_origin normalized_expected_origin
  normalized_origin=${origin%/}
  normalized_expected_origin=${expected_origin%/}
  normalized_origin=${normalized_origin%.git}
  normalized_expected_origin=${normalized_expected_origin%.git}
  normalized_origin=${normalized_origin#ssh://git@github.com/}
  normalized_expected_origin=${normalized_expected_origin#ssh://git@github.com/}
  normalized_origin=${normalized_origin#git@github.com:}
  normalized_expected_origin=${normalized_expected_origin#git@github.com:}
  normalized_origin=${normalized_origin#https://github.com/}
  normalized_expected_origin=${normalized_expected_origin#https://github.com/}
  [[ "$normalized_origin" == "$normalized_expected_origin" ]] || {
    echo "source origin does not match $expected_origin: $origin" >&2
    return 73
  }
  [[ "$(git -C "$source_root" rev-parse HEAD)" == "$expected_revision" ]] || {
    echo "source revision does not match $expected_revision: $source_root" >&2
    return 74
  }
  # The release builders run from WSL against Windows worktrees as well as
  # native Linux checkouts.  A Windows Git checkout can legitimately have a
  # CRLF working tree for a LF-committed source revision; WSL Git otherwise
  # reports every text file as modified.  Ignore *only* end-of-line whitespace
  # in this source-lock comparison, while still rejecting any content change.
  # A superproject's normal diff reports a submodule as dirty before it can
  # apply the end-of-line-only comparison above.  Check the superproject and
  # every initialized submodule separately: its recorded commit must match,
  # while a CRLF-only Windows checkout remains acceptable to the WSL builder.
  git -C "$source_root" diff --ignore-space-at-eol --ignore-submodules=dirty --quiet || {
    echo "source checkout has content changes: $source_root" >&2
    return 75
  }
  git -C "$source_root" diff --cached --ignore-space-at-eol --ignore-submodules=dirty --quiet || {
    echo "source checkout has staged content changes: $source_root" >&2
    return 76
  }
  local submodule_status submodule_marker submodule_path
  while IFS= read -r submodule_status; do
    [[ -n "$submodule_status" ]] || continue
    submodule_marker=${submodule_status:0:1}
    submodule_path=${submodule_status:42}
    submodule_path=${submodule_path%% (*}
    case "$submodule_marker" in
      ' ')
        git -C "$source_root/$submodule_path" diff --ignore-space-at-eol --quiet || {
          echo "source submodule has content changes: $source_root/$submodule_path" >&2
          return 78
        }
        git -C "$source_root/$submodule_path" diff --cached --ignore-space-at-eol --quiet || {
          echo "source submodule has staged content changes: $source_root/$submodule_path" >&2
          return 79
        }
        ;;
      -)
        # A non-recursive, commit-locked upstream clone can deliberately leave
        # an unused submodule uninitialized.  Its recorded commit remains
        # verified by the superproject revision; there is no local content to
        # inspect until a recipe explicitly initializes and consumes it.
        ;;
      *)
        echo "source submodule is absent, conflicted, or at a different commit: $source_root/$submodule_path" >&2
        return 77
        ;;
    esac
  done < <(git -C "$source_root" submodule status --recursive)
  printf '%s\n' "$source_root"
}

tdvp_copy_runtime_library() {
  local install_root=$1
  local payload_root=$2
  local library_glob=$3
  local source_library
  shopt -s nullglob
  local libraries=("$install_root"/usr/lib/$library_glob)
  shopt -u nullglob
  [[ ${#libraries[@]} -gt 0 ]] || {
    echo "no installed runtime library matched $library_glob" >&2
    return 77
  }
  mkdir -p -- "$payload_root/usr/lib"
  for source_library in "${libraries[@]}"; do
    cp -a -- "$source_library" "$payload_root/usr/lib/"
  done
}
