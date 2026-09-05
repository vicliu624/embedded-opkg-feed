#!/usr/bin/env bash
# Shared, transactional access to the locked Buildroot output used by a TDVP
# feed candidate.  A feed recipe may enable an additional target package, but
# it must leave the completed firmware configuration byte-for-byte unchanged
# when it returns.  This keeps feed work from leaking into the next firmware
# image build.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_buildroot_output_from_sdk() {
  local sdk_root=$1
  local configured_output=${2:-}
  local output
  [[ -d "$sdk_root" ]] || { echo "SDK root does not exist: $sdk_root" >&2; return 64; }
  sdk_root=$(cd -- "$sdk_root" && pwd)
  output=${configured_output:-$(cd -- "$sdk_root/.." && pwd)}
  [[ "$sdk_root" == "$output/host" && -f "$output/.config" && -f "$output/Makefile" && -d "$output/target" ]] || {
    echo 'the feed recipe needs a completed matching Buildroot output directory' >&2
    return 65
  }
  printf '%s\n' "$output"
}

tdvp_buildroot_tree_from_output() {
  local output=$1
  local tree
  tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$output/Makefile")
  [[ -n "$tree" && -d "$tree" && -x "$tree/utils/config" ]] || {
    echo "could not resolve the locked Buildroot tree from $output/Makefile" >&2
    return 66
  }
  printf '%s\n' "$tree"
}

tdvp_assert_buildroot_2025_02_1() {
  local tree=$1
  local version
  version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$tree/Makefile")
  [[ "$version" == '2025.02.1' ]] || {
    echo "expected locked Buildroot 2025.02.1, got ${version:-unknown}" >&2
    return 67
  }
}

# Usage:
#   tdvp_buildroot_install <output> <temporary-target-root> \
#     [--offline-download-dir <directory>] \
#     --enable CONFIG ... --disable CONFIG ... \
#     --make-variable NAME=value ... --target package ...
#
# When --offline-download-dir is supplied, package downloads are read only
# from that directory.  The caller is expected to seed it with artifacts that
# have already passed scripts/verify-source-lock.sh and fetch-source-cache.sh;
# Buildroot is prevented from falling back to an upstream mirror.
#
# The function runs in a subshell so its EXIT trap cannot affect the recipe
# that called it.  It intentionally dircleans only the requested Buildroot
# packages; stale feed builds are never accepted as evidence for an immutable
# release.
tdvp_buildroot_install() (
  set -Eeuo pipefail
  IFS=$'\n\t'
  local output=$1
  local target_root=$2
  shift 2
  local tree config_backup config_hash config_saved=0
  local config_old_backup= config_old_hash= config_old_saved=0 rc download_dir= base_download_dir=
  local -a enable=() disable=() make_variables=() targets=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable)
        [[ $# -ge 2 ]] || { echo '--enable needs a Buildroot symbol' >&2; exit 68; }
        enable+=("$2"); shift 2
        ;;
      --disable)
        [[ $# -ge 2 ]] || { echo '--disable needs a Buildroot symbol' >&2; exit 68; }
        disable+=("$2"); shift 2
        ;;
      --make-variable)
        [[ $# -ge 2 ]] || { echo '--make-variable needs NAME=value' >&2; exit 68; }
        # These are reviewed package-recipe inputs, not a shell escape hatch.
        # Values are passed as one make argv element, never evaluated by a
        # shell. Literal spaces are allowed for ordinary configure options;
        # quotes, dollars, and make-function syntax remain forbidden.
        [[ "$2" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9_./:+\ -]*$ ]] || {
          echo "invalid Buildroot make variable: $2" >&2
          exit 68
        }
        make_variables+=("$2"); shift 2
        ;;
      --target)
        [[ $# -ge 2 ]] || { echo '--target needs a Buildroot package name' >&2; exit 68; }
        targets+=("$2"); shift 2
        ;;
      --offline-download-dir)
        [[ $# -ge 2 ]] || { echo '--offline-download-dir needs a directory' >&2; exit 68; }
        [[ -z "$download_dir" ]] || { echo '--offline-download-dir may be supplied once' >&2; exit 68; }
        [[ -d "$2" && ! -L "$2" ]] || { echo "offline Buildroot download directory is not a regular directory: $2" >&2; exit 68; }
        download_dir=$(cd -- "$2" && pwd)
        shift 2
        ;;
      *)
        echo "unknown tdvp_buildroot_install option: $1" >&2; exit 68
        ;;
    esac
  done
  [[ ${#targets[@]} -gt 0 ]] || { echo 'tdvp_buildroot_install needs at least one --target' >&2; exit 69; }
  base_download_dir=${TDVP_BUILDROOT_BASE_DOWNLOAD_DIR:-}
  if [[ -n "$base_download_dir" ]]; then
    [[ -d "$base_download_dir" && ! -L "$base_download_dir" ]] || {
      echo "baseline Buildroot download directory is not a regular directory: $base_download_dir" >&2
      exit 69
    }
    base_download_dir=$(cd -- "$base_download_dir" && pwd)
  fi
  [[ -d "$target_root" && ! -L "$target_root" ]] || {
    echo "temporary Buildroot target root is not a regular directory: $target_root" >&2
    exit 69
  }
  # Package install rules normally run against Buildroot's populated target
  # skeleton. Feed extraction instead uses an empty private root, so create
  # the standard parent directories that a valid target already provides.
  # This affects only the caller's temporary TARGET_DIR, never the firmware
  # target or the SDK sysroot.
  mkdir -p -- "$target_root/bin" "$target_root/etc" "$target_root/sbin" "$target_root/usr/bin" \
    "$target_root/usr/lib" "$target_root/usr/sbin" "$target_root/usr/share"

  tdvp_buildroot_configure() {
    env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
      PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
      make -C "$output" olddefconfig
  }

  tdvp_buildroot_target_make() {
    if [[ -n "$download_dir" && -n "$base_download_dir" ]]; then
      env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
        PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        BR2_DL_DIR="$base_download_dir" \
        make -C "$output" \
          "BR2_PRIMARY_SITE=file://$download_dir" \
          BR2_PRIMARY_SITE_ONLY=y "${make_variables[@]}" "$@"
    elif [[ -n "$download_dir" ]]; then
      env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
        PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        BR2_DL_DIR="$download_dir" \
        make -C "$output" \
          "BR2_PRIMARY_SITE=file://$download_dir" \
          BR2_PRIMARY_SITE_ONLY=y "${make_variables[@]}" "$@"
    else
      env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
        PATH="$output/host/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
        make -C "$output" "${make_variables[@]}" "$@"
    fi
  }

  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  config_backup=$(mktemp "$output/.config.tdvp-feed.XXXXXX")
  config_hash=$(sha256sum "$output/.config" | awk '{print $1}')
  cleanup() {
    rc=$?
    set +e
    if [[ "$config_saved" -eq 1 ]]; then
      # Never call olddefconfig while restoring: a stale-but-user-owned SDK
      # config may be normalized by a newer/locally patched Kconfig tree.  The
      # transaction contract is byte-for-byte preservation of the input, not
      # silent migration of that input.
      cp --preserve=mode,timestamps -- "$config_backup" "$output/.config" || rc=98
      [[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
      if [[ "$config_old_saved" -eq 1 ]]; then
        cp --preserve=mode,timestamps -- "$config_old_backup" "$output/.config.old" || rc=100
        [[ "$(sha256sum "$output/.config.old" | awk '{print $1}')" == "$config_old_hash" ]] || rc=101
      elif [[ -e "$output/.config.old" || -L "$output/.config.old" ]]; then
        rm -f -- "$output/.config.old" || rc=102
      fi
    fi
    rm -f -- "$config_backup"
    [[ -z "$config_old_backup" ]] || rm -f -- "$config_old_backup"
    exit "$rc"
  }
  trap cleanup EXIT

  if [[ -e "$output/.config.old" || -L "$output/.config.old" ]]; then
    [[ -f "$output/.config.old" && ! -L "$output/.config.old" ]] || {
      echo "Buildroot config backup is not a regular file: $output/.config.old" >&2
      exit 76
    }
    config_old_backup=$(mktemp "$output/.config.old.tdvp-feed.XXXXXX")
    config_old_hash=$(sha256sum "$output/.config.old" | awk '{print $1}')
    cp --preserve=mode,timestamps -- "$output/.config.old" "$config_old_backup"
    config_old_saved=1
  fi
  cp --preserve=mode,timestamps -- "$output/.config" "$config_backup"; config_saved=1
  for symbol in "${enable[@]}"; do "$tree/utils/config" --file "$output/.config" --enable "$symbol"; done
  for symbol in "${disable[@]}"; do "$tree/utils/config" --file "$output/.config" --disable "$symbol"; done
  tdvp_buildroot_configure
  for symbol in "${enable[@]}"; do grep -Fqx "$symbol=y" "$output/.config" || { echo "Buildroot did not enable $symbol" >&2; exit 70; }; done
  for symbol in "${disable[@]}"; do
    if grep -Fqx "$symbol=y" "$output/.config"; then
      echo "Buildroot did not disable $symbol" >&2
      exit 71
    fi
  done
  for package in "${targets[@]}"; do
    tdvp_buildroot_target_make "${package}-dirclean"
    tdvp_buildroot_target_make TARGET_DIR="$target_root" "${package}-install-target"
  done
)

# Create a private Buildroot download directory containing every source
# artifact approved by a source.lock-backed package. Some target recipes also
# trigger baseline Buildroot host helpers. When TDVP_BUILDROOT_BASE_DOWNLOAD_DIR
# is set, those reviewed baseline inputs remain in that immutable cache, while
# this private directory is the primary site for the source.lock-approved
# package archives. It returns the private directory path on stdout; the
# caller owns and removes it. Copying, instead of linking, ensures an
# unexpected Buildroot cleanup can never modify TDVP's immutable source cache.
tdvp_prepare_locked_buildroot_download() {
  local package_dir=$1 repo_root verifier cache_root base_download_dir=
  local -a artifact_rows=()
  local artifact_row artifact_url artifact_file artifact_hash ignored cached_archive download_dir
  local -A seen_artifact_files=()

  [[ -d "$package_dir" ]] || { echo "package directory does not exist: $package_dir" >&2; return 71; }
  package_dir=$(cd -- "$package_dir" && pwd)
  [[ -f "$package_dir/source.lock" && ! -L "$package_dir/source.lock" ]] || {
    echo "locked Buildroot source requires source.lock: $package_dir" >&2
    return 71
  }
  : "${TDVP_SOURCE_CACHE_ROOT:?locked Buildroot source requires TDVP_SOURCE_CACHE_ROOT from scripts/build-all.sh}"
  [[ -d "$TDVP_SOURCE_CACHE_ROOT" && ! -L "$TDVP_SOURCE_CACHE_ROOT" ]] || {
    echo "TDVP_SOURCE_CACHE_ROOT is not a regular directory: $TDVP_SOURCE_CACHE_ROOT" >&2
    return 71
  }
  cache_root=$(cd -- "$TDVP_SOURCE_CACHE_ROOT" && pwd)
  base_download_dir=${TDVP_BUILDROOT_BASE_DOWNLOAD_DIR:-}
  if [[ -n "$base_download_dir" ]]; then
    [[ -d "$base_download_dir" && ! -L "$base_download_dir" ]] || {
      echo "baseline Buildroot download directory is not a regular directory: $base_download_dir" >&2
      return 71
    }
    base_download_dir=$(cd -- "$base_download_dir" && pwd)
  fi
  repo_root=$(cd -- "$package_dir/../.." && pwd)
  verifier="$repo_root/scripts/verify-source-lock.sh"
  [[ -f "$verifier" ]] || { echo "source lock verifier is missing: $verifier" >&2; return 71; }
  mapfile -t artifact_rows < <(bash "$verifier" --package-dir "$package_dir" --emit-artifacts)
  [[ ${#artifact_rows[@]} -gt 0 ]] || {
    echo "Buildroot package has no locked source artifact: $package_dir" >&2
    return 72
  }
  download_dir=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-buildroot-dl.XXXXXX")
  for artifact_row in "${artifact_rows[@]}"; do
    IFS=$'\t' read -r artifact_url artifact_file artifact_hash ignored <<<"$artifact_row"
    [[ -n "$artifact_url" && -n "$artifact_file" && -n "$artifact_hash" && -z "$ignored" ]] || {
      echo "could not parse locked Buildroot artifact: $package_dir" >&2
      rm -rf -- "$download_dir"
      return 72
    }
    [[ -z "${seen_artifact_files[$artifact_file]:-}" ]] || {
      echo "locked Buildroot artifacts use the same filename: $artifact_file" >&2
      rm -rf -- "$download_dir"
      return 72
    }
    seen_artifact_files[$artifact_file]=1
    cached_archive="$cache_root/sha256/$artifact_hash/$artifact_file"
    [[ -f "$cached_archive" && ! -L "$cached_archive" ]] || {
      echo "locked Buildroot archive is absent from cache: $cached_archive" >&2
      rm -rf -- "$download_dir"
      return 73
    }
    [[ "$(sha256sum "$cached_archive" | awk '{print $1}')" == "$artifact_hash" ]] || {
      echo "locked Buildroot archive hash differs in cache: $cached_archive" >&2
      rm -rf -- "$download_dir"
      return 74
    }
    if [[ -n "$base_download_dir" && -e "$base_download_dir/$artifact_file" ]]; then
      [[ -f "$base_download_dir/$artifact_file" && ! -L "$base_download_dir/$artifact_file" ]] && \
        [[ "$(sha256sum "$base_download_dir/$artifact_file" | awk '{print $1}')" == "$artifact_hash" ]] || {
          echo "baseline Buildroot archive differs from source.lock: $base_download_dir/$artifact_file" >&2
          rm -rf -- "$download_dir"
          return 74
        }
    fi
    if ! cp --no-preserve=mode -- "$cached_archive" "$download_dir/$artifact_file"; then
      rm -rf -- "$download_dir"
      return 75
    fi
    chmod 0444 "$download_dir/$artifact_file"
  done
  printf '%s\n' "$download_dir"
}
