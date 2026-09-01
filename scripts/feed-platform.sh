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
