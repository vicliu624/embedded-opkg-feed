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
source_cache_root=${TDVP_SOURCE_CACHE_ROOT:-}
offline_source_cache=${TDVP_SOURCE_CACHE_OFFLINE:-0}
require_source_locks=${TDVP_REQUIRE_SOURCE_LOCKS:-0}
runtime_catalog_only=0
reuse_runtime_catalog=0
requested_packages=()
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
    --source-cache)
      [[ $# -ge 2 ]] || { echo '--source-cache needs a value' >&2; exit 64; }
      source_cache_root=$2
      shift 2
      ;;
    --offline-source-cache)
      offline_source_cache=1
      shift
      ;;
    --require-source-locks)
      require_source_locks=1
      shift
      ;;
    --runtime-catalog-only)
      runtime_catalog_only=1
      shift
      ;;
    --reuse-runtime-catalog)
      reuse_runtime_catalog=1
      shift
      ;;
    --package)
      [[ $# -ge 2 ]] || { echo '--package needs a recipe name' >&2; exit 64; }
      requested_packages+=("$2")
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$output_root" ]] || {
  echo "usage: $0 --platform <platform-slug> [--release <rN>] --output <output-root> [--source-cache <directory>] [--offline-source-cache] [--require-source-locks] [--runtime-catalog-only|--reuse-runtime-catalog] [--package <recipe> ...]" >&2
  exit 64
}
[[ "$runtime_catalog_only" -eq 0 || "$reuse_runtime_catalog" -eq 0 ]] || {
  echo '--runtime-catalog-only and --reuse-runtime-catalog cannot be combined' >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
source_cache_root=${source_cache_root:-"$repo_root/.tdvp-source-cache"}
source_cache_root=$(mkdir -p -- "$source_cache_root" && cd -- "$source_cache_root" && pwd)
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

# r6 is the current composable-distribution release.  The completed firmware target
# is an input to the release, not an undeclared provider: all of its non-ABI
# runtime SONAMEs are copied byte-for-byte into independently versioned feed
# packages before any leaf application is packaged.
runtime_catalog_enabled=0
case "$release" in
  r[3-9]|r[1-9][0-9]*) runtime_catalog_enabled=1 ;;
esac
runtime_owner_map=
target_runtime_provider_manifest=
readelf_tool=
if [[ "$runtime_catalog_enabled" -eq 1 ]]; then
  [[ -n "$base_root" ]] || {
    echo 'composable runtime releases require TDVP_FEED_BASE_ROOT or TDVP_SDK_ROOT with a sibling target/' >&2
    exit 69
  }
  readelf_tool=${TDVP_READELF:-}
  if [[ -z "$readelf_tool" && -n "${TDVP_SDK_ROOT:-}" ]]; then
    readelf_tool="$TDVP_SDK_ROOT/bin/riscv64-unknown-linux-gnu-readelf"
  fi
  [[ -n "$readelf_tool" && -x "$readelf_tool" ]] || {
    echo 'composable runtime releases require the matching K230 readelf tool' >&2
    exit 70
  }
  if [[ "$reuse_runtime_catalog" -eq 1 ]]; then
    echo "reusing cached target-runtime catalogue: $feed_dir" >&2
  else
    TDVP_READELF="$readelf_tool" \
      bash "$script_dir/build-runtime-catalog.sh" --platform "$platform_slug" \
        --release "$release" --target-root "$base_root" --output "$feed_dir"
  fi
  runtime_owner_map="$feed_dir/.tdvp-runtime-owners.tsv"
  target_runtime_provider_manifest="$feed_dir/.tdvp-target-runtime-packages.tsv"
  [[ -s "$runtime_owner_map" ]] || {
    echo "runtime catalogue did not create its owner map: $runtime_owner_map" >&2
    exit 71
  }
  [[ -s "$target_runtime_provider_manifest" ]] || {
    echo "runtime catalogue did not create its target-provider manifest: $target_runtime_provider_manifest" >&2
    exit 72
  }
elif [[ "$runtime_catalog_only" -eq 1 || "$reuse_runtime_catalog" -eq 1 ]]; then
  echo "runtime-catalog options require a composable r3-or-newer release; got $release" >&2
  exit 69
fi

# A runtime base is deliberately private build input: it contains target-derived
# IPKs and the ownership maps needed by later partial batches, but no Packages
# index and no source-built recipe.  It is cacheable by platform ABI identity
# and must be copied into each incremental batch before --reuse-runtime-catalog.
if [[ "$runtime_catalog_only" -eq 1 ]]; then
  [[ ${#requested_packages[@]} -eq 0 ]] || {
    echo '--runtime-catalog-only does not accept --package' >&2
    exit 64
  }
  [[ ! -e "$feed_dir/Packages" && ! -e "$feed_dir/Packages.gz" ]] || {
    echo "runtime catalogue base must not contain a public Packages index: $feed_dir" >&2
    exit 65
  }
  echo "runtime catalogue base ready for incremental batches: $feed_dir"
  exit 0
fi

staging_root=$(mktemp -d)
cleanup() { rm -rf -- "$staging_root"; }
trap cleanup EXIT

declare -A recipe_dir=()
declare -A recipe_build_depends=()
declare -A recipe_runtime_depends=()
declare -A recipe_kind=()
declare -A build_state=()
declare -A force_source_build=()
declare -A target_runtime_provider=()
declare -A target_runtime_provider_sonames=()
declare -a available_packages=()
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

# PACKAGE_DEPENDS is deliberately human-readable (for example
# "sdl2 (= 2.30.11-2), libmgba (= 0.10.5-1)"). A selective build still
# needs every declared runtime package in its partial catalogue, so extract
# only the package name while leaving version validation to build-ipk and
# verify-feed. Build-only dependencies use the simpler documented
# space-delimited PACKAGE_BUILD_DEPENDS format below.
emit_runtime_dependency_names() {
  local package=$1 raw dependency
  local -a dependencies=()
  raw=${recipe_runtime_depends[$package]:-}
  [[ -n "$raw" ]] || return 0
  IFS=',' read -r -a dependencies <<< "$raw"
  for dependency in "${dependencies[@]}"; do
    dependency=${dependency#"${dependency%%[![:space:]]*}"}
    dependency=${dependency%"${dependency##*[![:space:]]}"}
    [[ "$dependency" =~ ^([a-z0-9][a-z0-9+.-]*) ]] || {
      echo "invalid PACKAGE_DEPENDS entry for $package: $dependency" >&2
      exit 77
    }
    printf '%s\n' "${BASH_REMATCH[1]}"
  done
}

# A selective source batch may depend on a data/runtime IPK that is derived
# directly from the completed K230 target and therefore has no recipe
# directory. It is already present after build-runtime-catalog.sh, so treat
# that exact package name as satisfied without inventing a source provider.
target_catalogue_has_package() {
  local package=$1
  find "$feed_dir" -maxdepth 1 -type f -name "${package}_*.ipk" -print -quit | grep -q .
}

# Target-derived runtime packages are the sole source of truth for their
# already-present SONAMEs.  Source recipes with exactly matching package and
# version metadata are intentionally deferred: compiling them would create a
# second provider and risk replacing the platform ABI.  The private catalogue
# file is produced by build-runtime-catalog.sh, not supplied by a caller.
if [[ -n "$target_runtime_provider_manifest" ]]; then
  while IFS='|' read -r package soname version; do
    package=${package%$'\r'}
    [[ -n "$package" && "$package" != \#* ]] || continue
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ && -n "$soname" && -n "$version" ]] || {
      echo "invalid target runtime provider record: $package" >&2
      exit 73
    }
    if [[ -n "${target_runtime_provider[$package]:-}" && "${target_runtime_provider[$package]}" != "$version" ]]; then
      echo "target runtime provider has conflicting SONAME versions: $package" >&2
      exit 73
    fi
    target_runtime_provider[$package]=$version
    target_runtime_provider_sonames[$package]+="$soname "
  done <"$target_runtime_provider_manifest"
fi

while IFS= read -r package_env; do
  package_dir=$(dirname -- "$package_env")
  package=$(read_recipe_value "$package_env" PACKAGE)
  supported_platforms=$(read_recipe_value "$package_env" SUPPORTED_PLATFORMS)
  package_releases=$(read_recipe_value "$package_env" PACKAGE_RELEASES)
  package_releases=${package_releases:-r1}
  package_kind=$(read_recipe_value "$package_env" PACKAGE_KIND)
  package_kind=${package_kind:-application}
  package_build_depends=$(read_recipe_value "$package_env" PACKAGE_BUILD_DEPENDS)
  package_runtime_depends=$(read_recipe_value "$package_env" PACKAGE_DEPENDS)

  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
    echo "invalid or missing PACKAGE in $package_env" >&2
    exit 66
  }
  if [[ " $supported_platforms " != *" $PLATFORM_SLUG "* ]] || \
     [[ " $package_releases " != *" $release "* ]]; then
    continue
  fi
  if [[ -n "${target_runtime_provider[$package]:-}" ]]; then
    target_version=${target_runtime_provider[$package]}
    target_sonames=${target_runtime_provider_sonames[$package]% }
    [[ "$package_kind" == shared-library || "$package_kind" == runtime ]] || {
      echo "target runtime provider collides with non-runtime recipe: $package" >&2
      exit 74
    }
    recipe_version=$(read_recipe_value "$package_env" VERSION)
    [[ "$recipe_version" == "$target_version" ]] || {
      echo "target runtime provider version is not attested for $package: target $target_sonames is $target_version, recipe is $recipe_version" >&2
      exit 74
    }
    echo "source runtime recipe deferred; target owns $target_sonames: $package ($target_version)" >&2
    continue
  fi
  [[ -z "${recipe_dir[$package]:-}" ]] || {
    echo "duplicate package name: $package" >&2
    exit 67
  }
  recipe_dir[$package]=$package_dir
  recipe_build_depends[$package]=$package_build_depends
  recipe_runtime_depends[$package]=$package_runtime_depends
  recipe_kind[$package]=$package_kind
  available_packages+=("$package")
done < <(find "$repo_root/packages" -mindepth 2 -maxdepth 2 -name package.env -type f -print | LC_ALL=C sort)

# With no --package arguments, retain the historical all-recipes behaviour.
# A repeated --package selects a source cohort root, then closes both its
# build-time and declared runtime dependencies. This makes a batch useful on
# its own: its Packages index cannot point at a recipe that the batch omitted.
declare -A selected_package=()
select_package_closure() {
  local package=$1 dependency
  local -a build_dependencies=()
  [[ -n "${target_runtime_provider[$package]:-}" ]] && return 0
  target_catalogue_has_package "$package" && return 0
  [[ -n "${recipe_dir[$package]:-}" ]] || {
    echo "selected package is neither a recipe nor a target-catalogue provider: $package" >&2
    exit 78
  }
  [[ "${selected_package[$package]:-0}" == 1 ]] && return 0
  selected_package[$package]=1

  IFS=' ' read -r -a build_dependencies <<< "${recipe_build_depends[$package]}"
  for dependency in "${build_dependencies[@]}"; do
    [[ -n "$dependency" ]] || continue
    select_package_closure "$dependency"
  done
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    select_package_closure "$dependency"
  done < <(emit_runtime_dependency_names "$package")
}

if [[ ${#requested_packages[@]} -eq 0 ]]; then
  selected_packages=("${available_packages[@]}")
else
  for package in "${requested_packages[@]}"; do
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
      echo "invalid --package value: $package" >&2
      exit 78
    }
    select_package_closure "$package"
  done
  for package in "${available_packages[@]}"; do
    [[ "${selected_package[$package]:-0}" == 1 ]] && selected_packages+=("$package")
  done
fi

[[ ${#selected_packages[@]} -gt 0 ]] || {
  echo "no package recipes support $platform_slug feed $release" >&2
  exit 68
}

# Validate every lock that is already present before invoking a package hook.
# A full legacy migration can opt into --require-source-locks; the CI changed
# recipe gate makes the record mandatory for newly changed package recipes
# without retroactively rewriting immutable historic releases.
for package in "${selected_packages[@]}"; do
  package_dir=${recipe_dir[$package]}
  if [[ -f "$package_dir/source.lock" ]]; then
    cache_arguments=(--cache "$source_cache_root" --package-dir "$package_dir")
    [[ "$offline_source_cache" -eq 0 ]] || cache_arguments+=(--offline)
    bash "$script_dir/fetch-source-cache.sh" "${cache_arguments[@]}"
  elif [[ "$require_source_locks" -eq 1 ]]; then
    source_lock_exempt_reason=$(read_recipe_value "$package_dir/package.env" SOURCE_LOCK_EXEMPT_REASON)
    [[ -n "$source_lock_exempt_reason" ]] || {
      echo "selected package has no source.lock or SOURCE_LOCK_EXEMPT_REASON: $package_dir" >&2
      exit 78
    }
    echo "source lock exempt: $package_dir" >&2
  fi
done

contains_shared_runtime=0
for package in "${selected_packages[@]}"; do
  [[ "${recipe_kind[$package]}" == shared-library ]] && contains_shared_runtime=1
done
if [[ "$contains_shared_runtime" -eq 1 && -z "$base_root" ]]; then
  echo 'shared-library releases require TDVP_FEED_BASE_ROOT or TDVP_SDK_ROOT with a sibling target/' >&2
  exit 72
fi

# A reused runtime IPK deliberately contains only runtime files. When a leaf
# package changes source, its compile-time dependencies must instead be built
# once into this release's ephemeral staging sysroot so headers, pkg-config
# metadata, and linker symlinks exist. Walk the declared build-dependency graph
# before scheduling packages; selected-package sort order must not decide
# whether a runtime is incorrectly reused before its source-built consumer.
mark_source_build_closure() {
  local package=$1
  local dependency
  local -a dependencies=()
  [[ -n "${target_runtime_provider[$package]:-}" ]] && return
  [[ -n "${recipe_dir[$package]:-}" ]] || {
    echo "source-built package depends on unavailable build package: $package" >&2
    exit 77
  }
  [[ "${force_source_build[$package]:-0}" == 1 ]] && return
  force_source_build[$package]=1
  IFS=' ' read -r -a dependencies <<< "${recipe_build_depends[$package]}"
  for dependency in "${dependencies[@]}"; do
    [[ -n "$dependency" ]] || continue
    mark_source_build_closure "$dependency"
  done
}

# Command recipes materialise their payload on a POSIX staging filesystem and
# expose it through packages/<name>/root, which can be a symlink when the
# repository itself is on Windows drvfs. Remove only our own verified staging
# directory after its IPK has been built; never follow an arbitrary recipe
# symlink while cleaning generated payloads.
discard_generated_payload() {
  local package_dir=$1 root_link resolved_payload temporary_prefix
  root_link="$package_dir/root"
  temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."
  if [[ -L "$root_link" ]]; then
    resolved_payload=$(readlink -f -- "$root_link" 2>/dev/null || true)
    if [[ "$resolved_payload" == "$temporary_prefix"* && -d "$resolved_payload" ]]; then
      rm -f -- "$root_link"
      rm -rf -- "$resolved_payload"
      return 0
    fi
  fi
  rm -rf -- "$root_link"
}

for package in "${selected_packages[@]}"; do
  if [[ -f "${recipe_dir[$package]}/build.sh" ]] && \
     [[ -z "$(read_recipe_value "${recipe_dir[$package]}/package.env" REUSE_IPK_URL)" ]]; then
    mark_source_build_closure "$package"
  fi
done

build_package() {
  local package=$1
  local dependency package_dir
  local -a build_dependencies=()
  case "${build_state[$package]:-unseen}" in
    done) return 0 ;;
    visiting)
      echo "package build dependency cycle includes: $package" >&2
      exit 73
      ;;
    unseen) ;;
    *)
      echo "invalid package build state for $package" >&2
      exit 74
      ;;
  esac
  [[ -n "${recipe_dir[$package]:-}" ]] || {
    echo "selected recipe depends on unavailable build package: $package" >&2
    exit 75
  }
  build_state[$package]=visiting
  # The script's global IFS intentionally excludes spaces for robust file
  # handling.  PACKAGE_BUILD_DEPENDS is a documented space-delimited field,
  # so split it explicitly instead of relying on the ambient IFS.
  IFS=' ' read -r -a build_dependencies <<< "${recipe_build_depends[$package]}"
  for dependency in "${build_dependencies[@]}"; do
    [[ -n "${target_runtime_provider[$dependency]:-}" ]] && continue
    [[ -n "${recipe_dir[$dependency]:-}" ]] || {
      echo "$package declares PACKAGE_BUILD_DEPENDS on $dependency, which is not selected for $release" >&2
      exit 76
    }
    build_package "$dependency"
  done

  package_dir=${recipe_dir[$package]}
  local reuse_published_payloads=${TDVP_REUSE_PUBLISHED_PAYLOADS:-1}
  # A strict offline release is a source-and-target rebuild, not a republish
  # that silently fetches a historical IPK. Source-locked recipes must use
  # their local cache/build path; target-derived recipes remain byte-identical
  # transfers under their explicit overlay policy.
  if [[ "$offline_source_cache" -eq 1 ]]; then
    reuse_published_payloads=0
  fi
  if [[ "${force_source_build[$package]:-0}" == 1 ]]; then
    reuse_published_payloads=0
  fi
  if [[ -f "$package_dir/build.sh" ]]; then
    TDVP_FEED_STAGING_ROOT="$staging_root" \
    TDVP_FEED_BASE_ROOT="$base_root" \
    TDVP_SOURCE_CACHE_ROOT="$source_cache_root" \
    TDVP_SOURCE_CACHE_OFFLINE="$offline_source_cache" \
    TDVP_REUSE_PUBLISHED_PAYLOADS="$reuse_published_payloads" \
    bash "$package_dir/build.sh" --platform "$platform_slug" --sdk-root "${TDVP_SDK_ROOT:-}"
  fi
  TDVP_FEED_BASE_ROOT="$base_root" \
  TDVP_RUNTIME_OWNER_MAP="$runtime_owner_map" \
  TDVP_READELF="$readelf_tool" \
    "$script_dir/build-ipk.sh" --platform "$platform_slug" "$package_dir" "$feed_dir"
  # Package build hooks materialise their payload under an ignored root/
  # directory so build-ipk can stay deliberately simple.  The signed IPK is
  # now complete; discard that transient tree before continuing so a growing
  # catalogue does not retain duplicate uncompressed library copies.
  if [[ -f "$package_dir/build.sh" ]]; then
    discard_generated_payload "$package_dir"
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
    bash "$script_dir/verify-runtime-closure.sh" --platform "$platform_slug" --base-root "$base_root" "$feed_dir"
  TDVP_SDK_ROOT="${TDVP_SDK_ROOT:-}" \
    "$script_dir/verify-target-runtime-coverage.sh" --platform "$platform_slug" --base-root "$base_root" "$feed_dir"
fi
# Owner-map and path-audit files are build evidence, not feed payload.  They
# must not be copied to GitHub Pages beside an immutable public index; the
# normal Packages catalogue is the public inventory.
rm -f -- "$feed_dir/.tdvp-runtime-owners.tsv" "$feed_dir/.tdvp-runtime-ownership.tsv" \
  "$feed_dir/.tdvp-target-runtime-packages.tsv"
echo "feed ready for offline signing: $feed_dir"
