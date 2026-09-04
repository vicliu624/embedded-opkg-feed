#!/usr/bin/env bash
# Validate the reviewable, non-executable source provenance record carried by
# a feed recipe. Do not source source.lock: it is PR input, so only the small
# KEY='value' grammar below is accepted.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  cat >&2 <<'EOF'
usage:
  verify-source-lock.sh --package-dir <packages/name> [--emit-artifacts]
  verify-source-lock.sh --repo-root <repo> --all [--require-source-locks]
  verify-source-lock.sh --repo-root <repo> --changed-since <git-revision>
EOF
}

die() {
  echo "source-lock: $*" >&2
  exit 64
}

package_dir=
repo_root=
mode=single
emit_artifacts=0
require_source_locks=0
changed_since=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-dir)
      [[ $# -ge 2 ]] || die '--package-dir needs a value'
      [[ -z "$package_dir" ]] || die '--package-dir may be supplied once'
      package_dir=$2
      shift 2
      ;;
    --repo-root)
      [[ $# -ge 2 ]] || die '--repo-root needs a value'
      [[ -z "$repo_root" ]] || die '--repo-root may be supplied once'
      repo_root=$2
      shift 2
      ;;
    --all)
      [[ "$mode" == single ]] || die 'select only one validation mode'
      mode=all
      shift
      ;;
    --changed-since)
      [[ $# -ge 2 ]] || die '--changed-since needs a Git revision'
      [[ "$mode" == single ]] || die 'select only one validation mode'
      mode=changed
      changed_since=$2
      shift 2
      ;;
    --require-source-locks)
      require_source_locks=1
      shift
      ;;
    --emit-artifacts)
      emit_artifacts=1
      shift
      ;;
    *)
      usage
      die "unknown argument: $1"
      ;;
  esac
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "$repo_root" ]]; then
  repo_root=$(cd -- "$script_dir/.." && pwd)
else
  repo_root=$(cd -- "$repo_root" && pwd)
fi

case "$mode" in
  single)
    [[ -n "$package_dir" ]] || { usage; die '--package-dir is required'; }
    [[ "$emit_artifacts" -eq 0 || "$require_source_locks" -eq 0 ]] || die '--require-source-locks is only meaningful with --all'
    ;;
  all|changed)
    [[ -z "$package_dir" ]] || die '--package-dir cannot be combined with --all or --changed-since'
    [[ "$emit_artifacts" -eq 0 ]] || die '--emit-artifacts is only available with --package-dir'
    ;;
esac

declare -A source_values=()
declare -A artifact_indices=()
declare -A patch_indices=()
declare -A build_input_indices=()
source_lock_path=
source_package_dir=

is_safe_value() {
  local value=$1
  [[ "$value" != *$'\t'* && "$value" != *$'\r'* && "$value" != *$'\n'* ]]
}

lock_value() {
  local key=$1
  printf '%s' "${source_values[$key]:-}"
}

require_value() {
  local key=$1 value
  value=$(lock_value "$key")
  [[ -n "$value" ]] || die "$source_lock_path is missing $key"
  printf '%s' "$value"
}

validate_source_lock() {
  source_package_dir=$(cd -- "$1" && pwd)
  source_lock_path="$source_package_dir/source.lock"
  [[ -f "$source_lock_path" && ! -L "$source_lock_path" ]] || die "missing regular source.lock: $source_lock_path"

  source_values=()
  artifact_indices=()
  patch_indices=()
  build_input_indices=()

  local raw_line line key value
  local line_number=0
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line=${raw_line%$'\r'}
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=\'([^\']*)\'$ ]]; then
      key=${BASH_REMATCH[1]}
      value=${BASH_REMATCH[2]}
    else
      die "$source_lock_path:$line_number must use the literal KEY='value' form"
    fi
    is_safe_value "$value" || die "$source_lock_path:$line_number contains a tab or control character"
    [[ -z "${source_values[$key]+x}" ]] || die "$source_lock_path:$line_number repeats $key"
    source_values[$key]=$value
  done <"$source_lock_path"

  local required_key
  for required_key in \
    FORMAT_VERSION SOURCE_TYPE UPSTREAM_NAME UPSTREAM_LICENSE UPSTREAM_VERSION \
    UPSTREAM_REVISION SOURCE_SNAPSHOT SOURCE_SELECTION_REASON SECURITY_STATUS \
    VERIFIED_BY VERIFIED_AT VERIFICATION_REFERENCE; do
    require_value "$required_key" >/dev/null
  done
  [[ "$(lock_value FORMAT_VERSION)" == 1 ]] || die "$source_lock_path has unsupported FORMAT_VERSION"

  local source_type revision snapshot
  source_type=$(lock_value SOURCE_TYPE)
  revision=$(lock_value UPSTREAM_REVISION)
  snapshot=$(lock_value SOURCE_SNAPSHOT)
  case "$source_type" in
    debian-source|buildroot-derived|git|release-tarball) ;;
    *) die "$source_lock_path has unsupported SOURCE_TYPE: $source_type" ;;
  esac
  [[ "$snapshot" == https://* && "$snapshot" != *' '* ]] || die "$source_lock_path SOURCE_SNAPSHOT must be an HTTPS URL"
  [[ "$revision" != main && "$revision" != master && "$revision" != develop && "$revision" != HEAD && "$revision" != latest ]] || {
    die "$source_lock_path UPSTREAM_REVISION must be immutable, not $revision"
  }
  if [[ "$source_type" == git || "$source_type" == buildroot-derived ]]; then
    [[ "$revision" =~ ^[0-9a-f]{40}$ ]] || {
      die "$source_lock_path $source_type source must use a full lowercase commit SHA"
    }
  fi
  [[ "$(lock_value VERIFIED_AT)" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || die "$source_lock_path VERIFIED_AT must be YYYY-MM-DD"

  local key index
  for key in "${!source_values[@]}"; do
    case "$key" in
      FORMAT_VERSION|SOURCE_TYPE|UPSTREAM_NAME|UPSTREAM_LICENSE|UPSTREAM_VERSION|UPSTREAM_REVISION|SOURCE_SNAPSHOT|SOURCE_SELECTION_REASON|NON_PLATFORM_BUILD_INPUTS|SECURITY_STATUS|VERIFIED_BY|VERIFIED_AT|VERIFICATION_REFERENCE)
        ;;
      SOURCE_ARTIFACT_*)
        if [[ "$key" =~ ^SOURCE_ARTIFACT_([1-9][0-9]*)_(URL|FILE|SHA256)$ ]]; then
          artifact_indices["${BASH_REMATCH[1]}"]=1
        else
          die "$source_lock_path has invalid artifact key: $key"
        fi
        ;;
      SOURCE_PATCH_*)
        if [[ "$key" =~ ^SOURCE_PATCH_([1-9][0-9]*)_(FILE|SHA256|REASON)$ ]]; then
          patch_indices["${BASH_REMATCH[1]}"]=1
        else
          die "$source_lock_path has invalid patch key: $key"
        fi
        ;;
      SOURCE_BUILD_INPUT_*)
        if [[ "$key" =~ ^SOURCE_BUILD_INPUT_([1-9][0-9]*)_(FILE|SHA256|REASON)$ ]]; then
          build_input_indices["${BASH_REMATCH[1]}"]=1
        else
          die "$source_lock_path has invalid build-input key: $key"
        fi
        ;;
      *) die "$source_lock_path has unknown key: $key" ;;
    esac
  done

  [[ ${#artifact_indices[@]} -gt 0 ]] || die "$source_lock_path must declare at least one source artifact"
  local -a ordered_indices=()
  mapfile -t ordered_indices < <(printf '%s\n' "${!artifact_indices[@]}" | LC_ALL=C sort -n)
  local expected=1 artifact_url artifact_file artifact_hash dsc_found=0
  for index in "${ordered_indices[@]}"; do
    [[ "$index" -eq "$expected" ]] || die "$source_lock_path artifact indices must be contiguous from 1"
    expected=$((expected + 1))
    artifact_url=$(require_value "SOURCE_ARTIFACT_${index}_URL")
    artifact_file=$(require_value "SOURCE_ARTIFACT_${index}_FILE")
    artifact_hash=$(require_value "SOURCE_ARTIFACT_${index}_SHA256")
    [[ "$artifact_url" == https://* && "$artifact_url" != *' '* ]] || die "$source_lock_path artifact $index URL must be HTTPS"
    [[ "$artifact_file" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ && "$artifact_file" != . && "$artifact_file" != .. ]] || {
      die "$source_lock_path artifact $index has unsafe filename: $artifact_file"
    }
    [[ "$artifact_hash" =~ ^[0-9a-f]{64}$ ]] || die "$source_lock_path artifact $index SHA-256 must be lowercase hex"
    [[ "$artifact_file" == *.dsc ]] && dsc_found=1
  done
  if [[ "$source_type" == debian-source ]]; then
    [[ "$dsc_found" -eq 1 ]] || die "$source_lock_path Debian source must include its .dsc artifact"
    [[ ${#artifact_indices[@]} -ge 2 ]] || die "$source_lock_path Debian source must include the .dsc and its source tarball artifacts"
  fi

  ordered_indices=()
  if [[ ${#patch_indices[@]} -gt 0 ]]; then
    mapfile -t ordered_indices < <(printf '%s\n' "${!patch_indices[@]}" | LC_ALL=C sort -n)
  fi
  expected=1
  local patch_file patch_hash patch_path actual_patch_hash
  for index in "${ordered_indices[@]}"; do
    [[ "$index" -eq "$expected" ]] || die "$source_lock_path patch indices must be contiguous from 1"
    expected=$((expected + 1))
    patch_file=$(require_value "SOURCE_PATCH_${index}_FILE")
    patch_hash=$(require_value "SOURCE_PATCH_${index}_SHA256")
    require_value "SOURCE_PATCH_${index}_REASON" >/dev/null
    [[ "$patch_file" =~ ^patches/[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || die "$source_lock_path patch $index must live directly under patches/"
    [[ "$patch_hash" =~ ^[0-9a-f]{64}$ ]] || die "$source_lock_path patch $index SHA-256 must be lowercase hex"
    patch_path="$source_package_dir/$patch_file"
    [[ -f "$patch_path" && ! -L "$patch_path" ]] || die "$source_lock_path patch $index is missing: $patch_file"
    actual_patch_hash=$(sha256sum "$patch_path" | awk '{print $1}')
    [[ "$actual_patch_hash" == "$patch_hash" ]] || die "$source_lock_path patch $index hash differs: $patch_file"
  done

  # Generated, non-executable local inputs such as a reviewed Go module
  # manifest are allowed only when the source lock pins their file hash. They
  # are not fetched artifacts and never authorize a recipe to evaluate them.
  ordered_indices=()
  if [[ ${#build_input_indices[@]} -gt 0 ]]; then
    mapfile -t ordered_indices < <(printf '%s\n' "${!build_input_indices[@]}" | LC_ALL=C sort -n)
  fi
  expected=1
  local build_input_file build_input_hash build_input_path actual_build_input_hash
  for index in "${ordered_indices[@]}"; do
    [[ "$index" -eq "$expected" ]] || die "$source_lock_path build-input indices must be contiguous from 1"
    expected=$((expected + 1))
    build_input_file=$(require_value "SOURCE_BUILD_INPUT_${index}_FILE")
    build_input_hash=$(require_value "SOURCE_BUILD_INPUT_${index}_SHA256")
    require_value "SOURCE_BUILD_INPUT_${index}_REASON" >/dev/null
    [[ "$build_input_file" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || die "$source_lock_path build input $index must be a direct package file"
    [[ "$build_input_hash" =~ ^[0-9a-f]{64}$ ]] || die "$source_lock_path build input $index SHA-256 must be lowercase hex"
    build_input_path="$source_package_dir/$build_input_file"
    [[ -f "$build_input_path" && ! -L "$build_input_path" ]] || die "$source_lock_path build input $index is missing: $build_input_file"
    actual_build_input_hash=$(sha256sum "$build_input_path" | awk '{print $1}')
    [[ "$actual_build_input_hash" == "$build_input_hash" ]] || die "$source_lock_path build input $index hash differs: $build_input_file"
  done

  echo "source lock valid: $source_package_dir" >&2
}

validate_changed_package() {
  local candidate_dir=$1 env_file exempt_line
  [[ -d "$candidate_dir" ]] || return 0
  env_file="$candidate_dir/package.env"
  [[ -f "$env_file" ]] || return 0
  if [[ -f "$candidate_dir/source.lock" ]]; then
    validate_source_lock "$candidate_dir"
    return 0
  fi
  exempt_line=$(grep -E "^SOURCE_LOCK_EXEMPT_REASON='[^']+'$" "$env_file" || true)
  [[ -n "$exempt_line" ]] || die "changed recipe lacks source.lock or SOURCE_LOCK_EXEMPT_REASON: $candidate_dir"
  echo "source lock exempt: $candidate_dir" >&2
}

case "$mode" in
  single)
    validate_source_lock "$package_dir"
    if [[ "$emit_artifacts" -eq 1 ]]; then
      mapfile -t ordered_indices < <(printf '%s\n' "${!artifact_indices[@]}" | LC_ALL=C sort -n)
      for index in "${ordered_indices[@]}"; do
        printf '%s\t%s\t%s\n' \
          "$(lock_value "SOURCE_ARTIFACT_${index}_URL")" \
          "$(lock_value "SOURCE_ARTIFACT_${index}_FILE")" \
          "$(lock_value "SOURCE_ARTIFACT_${index}_SHA256")"
      done
    fi
    ;;
  all)
    while IFS= read -r env_file; do
      candidate_dir=$(dirname -- "$env_file")
      if [[ -f "$candidate_dir/source.lock" ]]; then
        validate_source_lock "$candidate_dir"
      elif [[ "$require_source_locks" -eq 1 ]]; then
        validate_changed_package "$candidate_dir"
      fi
    done < <(find "$repo_root/packages" -mindepth 2 -maxdepth 2 -name package.env -type f -print | LC_ALL=C sort)
    ;;
  changed)
    command -v git >/dev/null || die 'git is required for --changed-since'
    git -C "$repo_root" rev-parse --verify --quiet "$changed_since^{commit}" >/dev/null || {
      die "unknown Git revision for --changed-since: $changed_since"
    }
    declare -A changed_package_dirs=()
    while IFS= read -r changed_path; do
      [[ "$changed_path" =~ ^packages/([^/]+)/ ]] || continue
      changed_package_dirs["${BASH_REMATCH[1]}"]=1
    done < <(git -C "$repo_root" diff --name-only --diff-filter=ACMR "$changed_since...HEAD" -- packages)
    if [[ ${#changed_package_dirs[@]} -eq 0 ]]; then
      echo 'source-lock: no changed package recipes' >&2
      exit 0
    fi
    mapfile -t ordered_indices < <(printf '%s\n' "${!changed_package_dirs[@]}" | LC_ALL=C sort)
    for package in "${ordered_indices[@]}"; do
      validate_changed_package "$repo_root/packages/$package"
    done
    ;;
esac
