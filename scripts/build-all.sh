#!/usr/bin/env bash
# Build one immutable feed release from an explicit package dependency graph.
# Shared runtime recipes are built once into a temporary SDK staging root;
# applications consume that staging root rather than rebuilding or bundling the
# same library again.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
output_root=
release=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --release)
      [[ $# -ge 2 ]] || { echo '--release needs a value' >&2; exit 64; }
      release=$2
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo '--output needs a value' >&2; exit 64; }
      output_root=$2
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$output_root" ]] || {
  echo "usage: $0 --platform <platform-slug> [--release <rN>] --output <output-root>" >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"
release=${release:-${DEFAULT_FEED_RELEASE:-r1}}
release_path=$(tdvp_feed_release_path "$release")

output_root=$(mkdir -p -- "$output_root" && cd -- "$output_root" && pwd)
feed_dir="$output_root/$release_path"
if [[ -e "$feed_dir/Packages" || -e "$feed_dir/Packages.gz" ]]; then
  echo "refusing to overwrite an existing immutable feed: $feed_dir" >&2
  exit 65
fi
mkdir -p -- "$feed_dir"

base_root=${TDVP_FEED_BASE_ROOT:-}
if [[ -z "$base_root" && -n "${TDVP_SDK_ROOT:-}" ]]; then
  candidate=$(cd -- "${TDVP_SDK_ROOT}/.." 2>/dev/null && pwd)/target
  [[ -d "$candidate" ]] && base_root=$candidate
fi
if [[ -n "$base_root" ]]; then
  base_root=$(cd -- "$base_root" && pwd)
fi

staging_root=$(mktemp -d)
cleanup() { rm -rf -- "$staging_root"; }
trap cleanup EXIT

declare -A recipe_dir=()
declare -A recipe_build_depends=()
declare -A recipe_kind=()
declare -A build_state=()
declare -a selected_packages=()

read_recipe_value() {
  local package_env=$1
  local variable=$2
  bash -c '
    set -Eeuo pipefail
    # shellcheck source=/dev/null
    source "$1"
    variable=$2
    printf "%s" "${!variable:-}"
  ' bash "$package_env" "$variable"
}

while IFS= read -r package_env; do
  package_dir=$(dirname -- "$package_env")
  package=$(read_recipe_value "$package_env" PACKAGE)
  supported_platforms=$(read_recipe_value "$package_env" SUPPORTED_PLATFORMS)
  package_releases=$(read_recipe_value "$package_env" PACKAGE_RELEASES)
  package_releases=${package_releases:-r1}
  package_kind=$(read_recipe_value "$package_env" PACKAGE_KIND)
  package_kind=${package_kind:-application}
  package_build_depends=$(read_recipe_value "$package_env" PACKAGE_BUILD_DEPENDS)

  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
    echo "invalid or missing PACKAGE in $package_env" >&2
    exit 66
  }
  if [[ " $supported_platforms " != *" $PLATFORM_SLUG "* ]] || \
     [[ " $package_releases " != *" $release "* ]]; then
    continue
  fi
  [[ -z "${recipe_dir[$package]:-}" ]] || {
    echo "duplicate selected package name: $package" >&2
    exit 67
  }
  recipe_dir[$package]=$package_dir
  recipe_build_depends[$package]=$package_build_depends
  recipe_kind[$package]=$package_kind
  selected_packages+=("$package")
done < <(find "$repo_root/packages" -mindepth 2 -maxdepth 2 -name package.env -type f -print | LC_ALL=C sort)

[[ ${#selected_packages[@]} -gt 0 ]] || {
  echo "no package recipes support $platform_slug feed $release" >&2
  exit 68
}

contains_shared_runtime=0
for package in "${selected_packages[@]}"; do
  [[ "${recipe_kind[$package]}" == shared-library ]] && contains_shared_runtime=1
done
if [[ "$contains_shared_runtime" -eq 1 && -z "$base_root" ]]; then
  echo 'shared-library releases require TDVP_FEED_BASE_ROOT or TDVP_SDK_ROOT with a sibling target/' >&2
  exit 69
fi

build_package() {
  local package=$1
  local dependency package_dir
  local -a build_dependencies=()
  case "${build_state[$package]:-unseen}" in
    done) return 0 ;;
    visiting)
      echo "package build dependency cycle includes: $package" >&2
      exit 70
      ;;
    unseen) ;;
    *)
      echo "invalid package build state for $package" >&2
      exit 71
      ;;
  esac
  [[ -n "${recipe_dir[$package]:-}" ]] || {
    echo "selected recipe depends on unavailable build package: $package" >&2
    exit 72
  }
  build_state[$package]=visiting
  # The script's global IFS intentionally excludes spaces for robust file
  # handling.  PACKAGE_BUILD_DEPENDS is a documented space-delimited field,
  # so split it explicitly instead of relying on the ambient IFS.
  IFS=' ' read -r -a build_dependencies <<< "${recipe_build_depends[$package]}"
  for dependency in "${build_dependencies[@]}"; do
    [[ -n "${recipe_dir[$dependency]:-}" ]] || {
      echo "$package declares PACKAGE_BUILD_DEPENDS on $dependency, which is not selected for $release" >&2
      exit 73
    }
    build_package "$dependency"
  done

  package_dir=${recipe_dir[$package]}
  if [[ -f "$package_dir/build.sh" ]]; then
    TDVP_FEED_STAGING_ROOT="$staging_root" \
    TDVP_FEED_BASE_ROOT="$base_root" \
      bash "$package_dir/build.sh" --platform "$platform_slug" --sdk-root "${TDVP_SDK_ROOT:-}"
  fi
  TDVP_FEED_BASE_ROOT="$base_root" \
    "$script_dir/build-ipk.sh" --platform "$platform_slug" "$package_dir" "$feed_dir"
  # Package build hooks materialise their payload under an ignored root/
  # directory so build-ipk can stay deliberately simple.  The signed IPK is
  # now complete; discard that transient tree before continuing so a growing
  # catalogue does not retain duplicate uncompressed library copies.
  if [[ -f "$package_dir/build.sh" ]]; then
    rm -rf -- "$package_dir/root"
  fi
  build_state[$package]=done
}

for package in "${selected_packages[@]}"; do
  build_package "$package"
done

"$script_dir/make-index.sh" "$feed_dir"
"$script_dir/verify-feed.sh" --platform "$platform_slug" "$feed_dir"
if [[ -n "$base_root" ]]; then
  TDVP_SDK_ROOT="${TDVP_SDK_ROOT:-}" \
    "$script_dir/verify-runtime-closure.sh" --platform "$platform_slug" --base-root "$base_root" "$feed_dir"
fi
echo "feed ready for offline signing: $feed_dir"
