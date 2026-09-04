#!/usr/bin/env bash
# Materialise one public runtime SONAME from a locked Buildroot source. The
# caller gives a single component instead of copying a bulk runtime: each
# reusable non-ABI library keeps one explicit IPK owner. A provider may also
# stage one named command emitted by that *same* source build for a separate
# leaf IPK; it is never included in the shared-library payload.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_build_archive_library() {
  local package_dir=$1
  local sdk_root=$2
  local configured_output=$3
  local config_symbol=$4
  local buildroot_package=$5
  local library_glob=$6
  local expected_source_line=$7
  shift 7
  local output install_root payload_dir= payload_link= previous_payload= temporary_prefix= download_dir= readelf_tool=
  local staged_command= stage_root= stage_destination= stage_marker= command_source=
  local payload_ready=0
  local -a install_options=() enable_options=() disable_options=() make_variable_options=()

  # The shared-library package is the only source builder. A split command
  # leaf can opt into exactly one /usr/bin command from that install root, and
  # may request only explicit additional Buildroot Kconfig symbols required to
  # make that command appear. This deliberately cannot stage a directory,
  # glob, arbitrary target path, or a second build output.
  enable_options+=(--enable "$config_symbol")
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --enable)
        [[ $# -ge 2 && "$2" =~ ^BR2_[A-Z0-9_]+$ ]] || {
          echo 'archive-library --enable requires one BR2_* symbol' >&2
          return 75
        }
        enable_options+=(--enable "$2")
        shift 2
        ;;
      --disable)
        [[ $# -ge 2 && "$2" =~ ^BR2_[A-Z0-9_]+$ ]] || {
          echo 'archive-library --disable requires one BR2_* symbol' >&2
          return 75
        }
        disable_options+=(--disable "$2")
        shift 2
        ;;
      --make-variable)
        # A reviewed recipe can override a narrow Buildroot package branch
        # while retaining the complete firmware Kconfig. The assignment is
        # passed as one make argv element; its conservative grammar excludes
        # shell substitution, quotes, and make-function syntax.
        [[ $# -ge 2 && "$2" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9_./:+\ -]*$ ]] || {
          echo 'archive-library --make-variable requires one safe NAME=value assignment' >&2
          return 75
        }
        make_variable_options+=(--make-variable "$2")
        shift 2
        ;;
      --stage-command)
        [[ $# -ge 2 && -z "$staged_command" && "$2" =~ ^/usr/bin/[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] || {
          echo 'archive-library --stage-command requires one clean /usr/bin command path' >&2
          return 75
        }
        staged_command=$2
        shift 2
        ;;
      *)
        echo "unknown archive-library option: $1" >&2
        return 75
        ;;
    esac
  done
  if [[ -n "$staged_command" ]]; then
    stage_root=${TDVP_FEED_STAGING_ROOT:-}
    [[ -n "$stage_root" && -d "$stage_root" && ! -L "$stage_root" ]] || {
      echo 'staged Buildroot command requires TDVP_FEED_STAGING_ROOT from build-all.sh' >&2
      return 75
    }
    stage_marker="$stage_root/.tdvp-buildroot-command-${buildroot_package}-${staged_command##*/}"
  fi

  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  # shellcheck source=elf-runtime-policy.sh
  source "$package_dir/../../support/elf-runtime-policy.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  # Do not fall back to the build host's readelf: payload sanitisation must
  # inspect the exact target ELF format emitted by the matched SDK.
  readelf_tool=${TDVP_READELF:-"$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"}
  [[ -x "$readelf_tool" ]] || {
    echo "matching SDK has no executable RISC-V readelf: $readelf_tool" >&2
    return 70
  }
  local tree
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx "$expected_source_line" "$tree/package/$buildroot_package/${buildroot_package}.mk" || {
    echo "locked Buildroot source differs from reviewed $buildroot_package recipe" >&2
    return 71
  }
  if [[ -f "$package_dir/source.lock" ]]; then
    download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
    install_options+=(--offline-download-dir "$download_dir")
  fi

  install_root=$(mktemp -d)
  payload_link="$package_dir/root"
  temporary_prefix=/tmp/tdvp-command-payload.
  cleanup_archive_library() {
    local rc=$?
    rm -rf -- "$install_root"
    [[ -z "$download_dir" ]] || rm -rf -- "$download_dir"
    if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
      rm -rf -- "$payload_dir"
      if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
        rm -f -- "$payload_link"
      fi
    fi
    return "$rc"
  }
  trap cleanup_archive_library RETURN
  tdvp_buildroot_install "$output" "$install_root" "${install_options[@]}" \
    "${enable_options[@]}" "${disable_options[@]}" "${make_variable_options[@]}" \
    --target "$buildroot_package"
  compgen -G "$install_root/usr/lib/$library_glob" >/dev/null || {
    echo "$buildroot_package target install omitted $library_glob" >&2
    return 72
  }
  if [[ -n "$staged_command" ]]; then
    command_source="$install_root$staged_command"
    [[ -f "$command_source" && ! -L "$command_source" && -x "$command_source" ]] || {
      echo "$buildroot_package target install omitted staged command: $staged_command" >&2
      return 76
    }
    "$readelf_tool" -h "$command_source" 2>/dev/null | grep -Fq 'Machine:                           RISC-V' || {
      echo "$buildroot_package staged a non-RISC-V command: $staged_command" >&2
      return 77
    }
    tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$command_source"
    tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$command_source"
    stage_destination="$stage_root$staged_command"
    [[ ! -e "$stage_destination" && ! -L "$stage_destination" && \
       ! -e "$stage_marker" && ! -L "$stage_marker" ]] || {
      echo "refusing to replace an existing staged Buildroot command: $staged_command" >&2
      return 78
    }
    mkdir -p -- "$(dirname -- "$stage_destination")"
    install -m 0755 -- "$command_source" "$stage_destination"
    printf '%s\n' \
      'format=1' \
      "source-package=$(basename -- "$package_dir")" \
      "buildroot-package=$buildroot_package" \
      "command=$staged_command" \
      >"$stage_marker"
  fi
  # Preserve target modes and ELF symlinks on a POSIX staging filesystem. The
  # repository can live on Windows drvfs, where copying to root/ would turn a
  # 0644/0755 runtime payload into mode 0777 before it reaches the IPK.
  if [[ -e "$payload_link" || -L "$payload_link" ]]; then
    [[ -L "$payload_link" ]] || {
      echo "refusing to replace non-generated payload path: $payload_link" >&2
      return 73
    }
    previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
    [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]] || {
      echo "refusing to replace unexpected payload target: $previous_payload" >&2
      return 74
    }
    rm -f -- "$payload_link"
    rm -rf -- "$previous_payload"
  fi
  payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
  chmod 0755 -- "$payload_dir"
  ln -s -- "$payload_dir" "$payload_link"
  mkdir -p -- "$payload_dir/usr/lib"
  cp -a "$install_root/usr/lib/"$library_glob "$payload_dir/usr/lib/"
  # Libtool may retain an SDK-directory DT_RPATH in a target library.  This
  # is build-location leakage, not a device runtime dependency.  Remove the
  # dynamic tags and immediately re-check the target object before build-ipk
  # derives its dependency closure.
  while IFS= read -r -d '' elf; do
    tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$elf"
  done < <(find "$payload_dir/usr/lib" -maxdepth 1 -type f -print0 | LC_ALL=C sort -z)
  payload_ready=1
  echo "$(basename "$package_dir") payload ready: $payload_dir"
}
