#!/usr/bin/env bash
# Shared immutable-platform and feed-channel helpers.  A platform ABI and a
# feed publication revision are deliberately separate concepts: a new package
# catalogue must never claim that the firmware ABI changed merely because an
# additional application or shared runtime became available.
set -Eeuo pipefail

tdvp_load_platform() {
  local repo_root=$1
  local platform_slug=$2
  local platform_file="$repo_root/platforms/$platform_slug/platform.env"

  [[ -f "$platform_file" ]] || {
    echo "unknown platform: $platform_slug" >&2
    return 65
  }

  # shellcheck source=/dev/null
  source "$platform_file"
  [[ "$platform_slug" == "$PLATFORM_SLUG" ]] || {
    echo "platform manifest slug mismatch: $platform_slug" >&2
    return 66
  }
}

# Native generators are build-host requirements, separate from target libraries.
# Keep recipe variables scoped to this check and split independently of caller IFS.
tdvp_assert_package_host_dependencies() (
  local package_dir=$1 dependency
  local -a dependencies=()
  source "$package_dir/package.env"
  IFS=' ' read -r -a dependencies <<< "${PACKAGE_HOST_DEPENDS:-}"
  for dependency in "${dependencies[@]}"; do
    [[ "$dependency" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
      echo "invalid build-host command for ${PACKAGE:-unknown}: $dependency" >&2
      exit 78
    }
    command -v -- "$dependency" >/dev/null || {
      echo "${PACKAGE:-unknown} requires build-host command: $dependency (PACKAGE_HOST_DEPENDS)" >&2
      exit 78
    }
  done
)

tdvp_feed_release_path() {
  local release=$1
  case "$release" in
    r1)
      # The first public release predates feed revisions.  Keep its URL byte
      # for byte stable forever.
      printf '%s/%s\n' "$PLATFORM_ID" "$ARCH"
      ;;
    r[2-9]|r[1-9][0-9]*)
      printf '%s/%s/%s\n' "$PLATFORM_ID" "$release" "$ARCH"
      ;;
    *)
      echo "invalid immutable feed release: $release" >&2
      return 67
      ;;
  esac
}

tdvp_feed_release_id() {
  local release=$1
  if [[ "$release" == r1 ]]; then
    printf '%s\n' "$PLATFORM_ID"
  else
    printf '%s/%s\n' "$PLATFORM_ID" "$release"
  fi
}

tdvp_feed_channel_path() {
  local channel=$1

  # A channel is deliberately distinct from an immutable rN snapshot.  Images
  # may keep this path for the lifetime of one firmware ABI while release
  # maintainers promote a complete, already-signed snapshot through it.
  case "$channel" in
    stable)
      printf '%s/%s/%s\n' "$PLATFORM_ID" "$channel" "$ARCH"
      ;;
    *)
      echo "invalid TDVP feed channel: $channel" >&2
      return 68
      ;;
  esac
}
