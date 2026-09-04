#!/usr/bin/env bash
# Reproducible Go-module input handling for source-built TDVP applications.
#
# A Go application's upstream source archive locks go.mod and go.sum, but it
# normally fetches its transitive module graph during `go build`.  That would
# make an otherwise immutable feed recipe network-dependent.  This helper
# derives a deterministic vendor bundle from those locked files using one
# reviewed host Go distribution, validates its hash, and stores it in the
# content-addressed source cache.  Target compilation always consumes the
# bundle with GOPROXY=off; the host Go distribution is never copied into an
# IPK payload.
set -Eeuo pipefail
IFS=$'\n\t'

declare -A TDVP_GO_VENDOR_LOCK_VALUES=()

tdvp_load_go_module_vendor_lock() {
  local package_dir=$1 lock_path
  lock_path="$package_dir/go-modules.lock"
  local raw_line line key value line_number=0
  local -a required_keys=(
    FORMAT_VERSION
    GO_TOOLCHAIN_VERSION
    GO_TOOLCHAIN_HOST_OS
    GO_TOOLCHAIN_HOST_ARCH
    GO_TOOLCHAIN_ARCHIVE
    GO_TOOLCHAIN_ARCHIVE_SHA256
    GO_MOD_SHA256
    GO_SUM_SHA256
    GO_RESOLVED_SUM_SHA256
    GO_VENDOR_MODULES_SHA256
    GO_VENDOR_MODULE_COUNT
    GO_MODULE_VENDOR_ARCHIVE
    GO_MODULE_VENDOR_ARCHIVE_SHA256
  )

  [[ -f "$lock_path" && ! -L "$lock_path" ]] || {
    echo "Go module lock is missing or unsafe: $lock_path" >&2
    return 64
  }
  TDVP_GO_VENDOR_LOCK_VALUES=()
  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line_number=$((line_number + 1))
    line=${raw_line%$'\r'}
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ ^([A-Z][A-Z0-9_]*)=\'([^\']*)\'$ ]]; then
      key=${BASH_REMATCH[1]}
      value=${BASH_REMATCH[2]}
    else
      echo "Go module lock must use literal KEY='value' syntax: $lock_path:$line_number" >&2
      return 65
    fi
    case "$key" in
      FORMAT_VERSION|GO_TOOLCHAIN_VERSION|GO_TOOLCHAIN_HOST_OS|GO_TOOLCHAIN_HOST_ARCH|GO_TOOLCHAIN_ARCHIVE|GO_TOOLCHAIN_ARCHIVE_SHA256|GO_MOD_SHA256|GO_SUM_SHA256|GO_RESOLVED_SUM_SHA256|GO_VENDOR_MODULES_SHA256|GO_VENDOR_MODULE_COUNT|GO_MODULE_VENDOR_ARCHIVE|GO_MODULE_VENDOR_ARCHIVE_SHA256)
        ;;
      *)
        echo "Go module lock has an unknown key: $lock_path:$line_number" >&2
        return 66
        ;;
    esac
    [[ -z "${TDVP_GO_VENDOR_LOCK_VALUES[$key]+x}" ]] || {
      echo "Go module lock repeats a key: $lock_path:$line_number" >&2
      return 67
    }
    [[ "$value" != *$'\t'* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || {
      echo "Go module lock contains a control character: $lock_path:$line_number" >&2
      return 68
    }
    TDVP_GO_VENDOR_LOCK_VALUES[$key]=$value
  done <"$lock_path"

  for key in "${required_keys[@]}"; do
    [[ -n "${TDVP_GO_VENDOR_LOCK_VALUES[$key]:-}" ]] || {
      echo "Go module lock is missing $key: $lock_path" >&2
      return 69
    }
  done
  [[ "${TDVP_GO_VENDOR_LOCK_VALUES[FORMAT_VERSION]}" == 1 ]] || {
    echo "unsupported Go module lock format: $lock_path" >&2
    return 70
  }
  [[ "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_VERSION]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Go module lock has an invalid Go toolchain version: $lock_path" >&2
    return 71
  }
  [[ "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_HOST_OS]}" == linux && \
     "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_HOST_ARCH]}" == amd64 ]] || {
    echo "Go module lock currently supports only the reviewed linux/amd64 host toolchain: $lock_path" >&2
    return 72
  }
  for key in GO_TOOLCHAIN_ARCHIVE GO_MODULE_VENDOR_ARCHIVE; do
    [[ "${TDVP_GO_VENDOR_LOCK_VALUES[$key]}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
      echo "Go module lock has an unsafe archive name for $key: $lock_path" >&2
      return 73
    }
  done
  for key in GO_TOOLCHAIN_ARCHIVE_SHA256 GO_MOD_SHA256 GO_SUM_SHA256 GO_RESOLVED_SUM_SHA256 GO_VENDOR_MODULES_SHA256 GO_MODULE_VENDOR_ARCHIVE_SHA256; do
    [[ "${TDVP_GO_VENDOR_LOCK_VALUES[$key]}" =~ ^[0-9a-f]{64}$ ]] || {
      echo "Go module lock has an invalid SHA-256 for $key: $lock_path" >&2
      return 74
    }
  done
  [[ "${TDVP_GO_VENDOR_LOCK_VALUES[GO_VENDOR_MODULE_COUNT]}" =~ ^[1-9][0-9]*$ ]] || {
    echo "Go module lock has an invalid vendor module count: $lock_path" >&2
    return 75
  }
}

tdvp_go_module_vendor_cache_file() {
  local cache_root=${TDVP_SOURCE_CACHE_ROOT:-}
  [[ -n "$cache_root" && -d "$cache_root" && ! -L "$cache_root" ]] || {
    echo 'Go module vendor cache requires a regular TDVP_SOURCE_CACHE_ROOT' >&2
    return 76
  }
  cache_root=$(cd -- "$cache_root" && pwd -P)
  printf '%s/derived/go-module-vendor/sha256/%s/%s\n' \
    "$cache_root" \
    "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}" \
    "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE]}"
}

tdvp_assert_go_vendor_source_hashes() {
  local source_root=$1 actual
  for key in GO_MOD_SHA256 GO_SUM_SHA256; do
    case "$key" in
      GO_MOD_SHA256) actual=$(sha256sum "$source_root/go.mod" | awk '{print $1}') ;;
      GO_SUM_SHA256) actual=$(sha256sum "$source_root/go.sum" | awk '{print $1}') ;;
    esac
    [[ "$actual" == "${TDVP_GO_VENDOR_LOCK_VALUES[$key]}" ]] || {
      echo "Go source module input changed ($key): $source_root" >&2
      return 77
    }
  done
}

tdvp_assert_go_vendor_resolved_sum() {
  local source_root=$1 actual
  actual=$(sha256sum "$source_root/go.sum" | awk '{print $1}')
  [[ "$actual" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_RESOLVED_SUM_SHA256]}" ]] || {
    echo "Go module resolution produced an unexpected go.sum: $source_root" >&2
    return 78
  }
}

tdvp_assert_go_vendor_tree() {
  local source_root=$1 actual module_count
  [[ -f "$source_root/vendor/modules.txt" && ! -L "$source_root/vendor/modules.txt" ]] || {
    echo "Go vendor bundle has no vendor/modules.txt: $source_root" >&2
    return 78
  }
  actual=$(sha256sum "$source_root/vendor/modules.txt" | awk '{print $1}')
  [[ "$actual" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_VENDOR_MODULES_SHA256]}" ]] || {
    echo "Go vendor/modules.txt hash differs from the lock: $source_root" >&2
    return 79
  }
  module_count=$(grep -c '^# ' "$source_root/vendor/modules.txt" || true)
  [[ "$module_count" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_VENDOR_MODULE_COUNT]}" ]] || {
    echo "Go vendor module count differs from the lock: $source_root" >&2
    return 80
  }
}

tdvp_prepare_locked_go_host_toolchain() {
  local package_dir=$1 work_root=$2 archive host_root go_binary
  # shellcheck source=source-archive-library.sh
  source "$package_dir/../../support/source-archive-library.sh"
  archive=$(tdvp_source_archive_locked_file "$package_dir" "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_ARCHIVE]}")
  [[ "$(sha256sum "$archive" | awk '{print $1}')" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_ARCHIVE_SHA256]}" ]] || {
    echo "locked Go host archive hash differs from go-modules.lock: $archive" >&2
    return 81
  }
  host_root="$work_root/go-host"
  mkdir -p -- "$host_root"
  tar -xzf "$archive" -C "$host_root"
  go_binary="$host_root/go/bin/go"
  [[ -x "$go_binary" && ! -L "$go_binary" ]] || {
    echo "locked Go host archive did not contain go/bin/go: $archive" >&2
    return 82
  }
  [[ "$("$go_binary" env GOVERSION)" == "go${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_VERSION]}" ]] || {
    echo "locked Go host toolchain version differs from go-modules.lock: $go_binary" >&2
    return 83
  }
  [[ "$("$go_binary" env GOOS)" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_HOST_OS]}" && \
     "$("$go_binary" env GOARCH)" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_TOOLCHAIN_HOST_ARCH]}" ]] || {
    echo "locked Go host toolchain platform differs from go-modules.lock: $go_binary" >&2
    return 84
  }
  printf '%s\n' "$go_binary"
}

tdvp_prepare_go_module_vendor_cache() {
  local source_root=$1 go_binary=$2 work_root=$3 cache_file cache_dir temporary actual_archive_hash
  [[ -d "$source_root" && ! -L "$source_root" ]] || {
    echo "Go module vendor source root is unsafe: $source_root" >&2
    return 85
  }
  [[ -x "$go_binary" && ! -L "$go_binary" ]] || {
    echo "Go module vendor host tool is unsafe: $go_binary" >&2
    return 86
  }
  tdvp_assert_go_vendor_source_hashes "$source_root"
  cache_file=$(tdvp_go_module_vendor_cache_file)
  cache_dir=$(dirname -- "$cache_file")
  if [[ -e "$cache_file" || -L "$cache_file" ]]; then
    [[ -f "$cache_file" && ! -L "$cache_file" ]] || {
      echo "Go module vendor cache entry is unsafe: $cache_file" >&2
      return 87
    }
    [[ "$(sha256sum "$cache_file" | awk '{print $1}')" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}" ]] || {
      echo "Go module vendor cache hash differs from go-modules.lock: $cache_file" >&2
      return 88
    }
    printf '%s\n' "$cache_file"
    return 0
  fi
  [[ "${TDVP_SOURCE_CACHE_OFFLINE:-0}" != 1 ]] || {
    echo "offline Go module vendor cache miss: $cache_file" >&2
    return 89
  }
  mkdir -p -- "$cache_dir"
  [[ -d "$cache_dir" && ! -L "$cache_dir" ]] || {
    echo "Go module vendor cache directory is unsafe: $cache_dir" >&2
    return 90
  }
  rm -rf -- "$source_root/vendor"
  (
    local_module_cache=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-go-module-cache.XXXXXX")
    local_go_cache=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-go-build-cache.XXXXXX")
    cleanup_go_module_vendor_work_cache() {
      local rc=$?
      # Go deliberately makes downloaded module trees read-only. They are
      # ephemeral cache-seed inputs here, so restore owner write permission
      # before deleting rather than leaving multi-gigabyte residue on failure.
      chmod -R u+w -- "$local_module_cache" "$local_go_cache" 2>/dev/null || true
      rm -rf -- "$local_module_cache" "$local_go_cache"
      exit "$rc"
    }
    trap cleanup_go_module_vendor_work_cache EXIT
    cd -- "$source_root"
    env \
      GOTOOLCHAIN=local \
      GOMODCACHE="$local_module_cache" \
      GOCACHE="$local_go_cache" \
      GOPROXY='https://proxy.golang.org' \
      GOSUMDB='sum.golang.org' \
      "$go_binary" mod download all
    env \
      GOTOOLCHAIN=local \
      GOMODCACHE="$local_module_cache" \
      GOCACHE="$local_go_cache" \
      GOPROXY='https://proxy.golang.org' \
      GOSUMDB='sum.golang.org' \
      "$go_binary" mod verify
    env \
      GOTOOLCHAIN=local \
      GOMODCACHE="$local_module_cache" \
      GOCACHE="$local_go_cache" \
      GOPROXY='https://proxy.golang.org' \
      GOSUMDB='sum.golang.org' \
      "$go_binary" mod vendor
  )
  tdvp_assert_go_vendor_resolved_sum "$source_root"
  tdvp_assert_go_vendor_tree "$source_root"
  temporary=$(mktemp "$cache_dir/.${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE]}.XXXXXX")
  (
    cd -- "$source_root"
    tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner --format=gnu \
      -cf - vendor | gzip -n >"$temporary"
  )
  actual_archive_hash=$(sha256sum "$temporary" | awk '{print $1}')
  [[ "$actual_archive_hash" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}" ]] || {
    rm -f -- "$temporary"
    echo "generated Go vendor bundle is not reproducible from the locked inputs: $source_root" >&2
    echo "Go vendor bundle SHA-256 expected ${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}, got $actual_archive_hash" >&2
    return 91
  }
  chmod 0444 -- "$temporary"
  if [[ -e "$cache_file" || -L "$cache_file" ]]; then
    [[ -f "$cache_file" && ! -L "$cache_file" && \
       "$(sha256sum "$cache_file" | awk '{print $1}')" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}" ]] || {
      rm -f -- "$temporary"
      echo "concurrent Go module vendor cache entry is unsafe: $cache_file" >&2
      return 92
    }
    rm -f -- "$temporary"
  else
    mv -- "$temporary" "$cache_file"
  fi
  printf '%s\n' "$cache_file"
}

tdvp_extract_go_module_vendor_cache() {
  local source_root=$1 cache_file=$2 entry
  [[ -f "$cache_file" && ! -L "$cache_file" ]] || {
    echo "Go module vendor cache entry is unsafe: $cache_file" >&2
    return 93
  }
  [[ "$(sha256sum "$cache_file" | awk '{print $1}')" == "${TDVP_GO_VENDOR_LOCK_VALUES[GO_MODULE_VENDOR_ARCHIVE_SHA256]}" ]] || {
    echo "Go module vendor cache hash differs from go-modules.lock: $cache_file" >&2
    return 94
  }
  while IFS= read -r entry; do
    [[ "$entry" == vendor/ || "$entry" == vendor/* ]] || {
      echo "Go vendor archive has an unsafe member outside vendor/: $entry" >&2
      return 95
    }
    [[ "$entry" != *'//'* && "$entry" != *'/../'* && "$entry" != ../* && "$entry" != *'/..' ]] || {
      echo "Go vendor archive has an unsafe member path: $entry" >&2
      return 96
    }
  done < <(tar -tzf "$cache_file")
  rm -rf -- "$source_root/vendor"
  tar -xzf "$cache_file" --no-same-owner --no-same-permissions -C "$source_root"
  tdvp_assert_go_vendor_tree "$source_root"
}
