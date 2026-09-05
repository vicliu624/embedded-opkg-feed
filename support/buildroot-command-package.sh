#!/usr/bin/env bash
# Build one ordinary command suite from the locked Buildroot tree.  The suite
# is installed below /usr/libexec/tdvp-<package>.  A standard /usr/bin
# frontend is emitted only when the baseline owns no such path; recipes whose
# command name is already a BusyBox applet must declare an explicit, distinct
# frontend name and let the immutable-base check enforce it.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_buildroot_command_package() {
  local package_dir=$1 sdk_root=$2 configured_output=$3 config_symbol=$4
  local buildroot_package=$5 source_line=$6 commands=$7
  local output tree install_root payload_dir= root_link= previous_payload= temporary_prefix= download_dir= command source destination link_target disabled_symbol make_variable frontend_name frontend_mapping mapping_source mapping_frontend
  local payload_ready=0
  local readelf_tool asset source_asset destination_asset
  local -a command_list=() asset_list=() install_options=() disable_options=() disabled_symbols=() make_variable_options=() make_variables=() frontend_mappings=()
  local -A public_frontends=() explicit_frontends=() frontend_owners=()
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  # shellcheck source=elf-runtime-policy.sh
  source "$package_dir/../../support/elf-runtime-policy.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
  [[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; return 79; }
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx "$source_line" "$tree/package/$buildroot_package/${buildroot_package}.mk" || {
    echo "locked Buildroot source differs from reviewed $buildroot_package recipe" >&2
    return 80
  }
  if [[ -f "$package_dir/source.lock" ]]; then
    download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
    install_options+=(--offline-download-dir "$download_dir")
  fi
  # A leaf command must not silently inherit an optional Buildroot feature
  # whose shared runtime has not been admitted into this feed. Recipes may
  # name a reviewed, space-delimited set of BR2 symbols to turn off here.
  if [[ -n "${TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS:-}" ]]; then
    IFS=' ' read -r -a disabled_symbols <<< "$TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS"
    for disabled_symbol in "${disabled_symbols[@]}"; do
      [[ "$disabled_symbol" =~ ^BR2_[A-Z0-9_]+$ ]] || {
        echo "invalid Buildroot command-package disable symbol: $disabled_symbol" >&2
        return 84
      }
      disable_options+=(--disable "$disabled_symbol")
    done
  fi
  # A package may need to override one narrow Buildroot recipe branch while
  # preserving the completed firmware configuration. For example, iperf3's
  # plaintext candidate must force --without-openssl even when the desktop
  # firmware itself legitimately selects OpenSSL. The environment variable is
  # newline-delimited so one reviewed assignment can carry ordinary configure
  # options separated by spaces. Values are passed to make, not evaluated by a
  # shell, and use the same conservative grammar enforced by
  # tdvp_buildroot_install.
  if [[ -n "${TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES:-}" ]]; then
    while IFS= read -r make_variable || [[ -n "$make_variable" ]]; do
      [[ -n "$make_variable" ]] || continue
      [[ "$make_variable" =~ ^[A-Z][A-Z0-9_]*=[A-Za-z0-9_./:+\ -]*$ ]] || {
        echo "invalid Buildroot command-package make variable: $make_variable" >&2
        return 85
      }
      make_variable_options+=(--make-variable "$make_variable")
    done <<< "$TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES"
  fi
  install_root=$(mktemp -d)
  root_link="$package_dir/root"
  temporary_prefix="${TMPDIR:-/tmp}/tdvp-command-payload."
  cleanup_command_package() {
    local rc=$?
    rm -rf -- "$install_root"
    [[ -z "$download_dir" ]] || rm -rf -- "$download_dir"
    if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
      rm -rf -- "$payload_dir"
      if [[ -L "$root_link" && "$(readlink -f -- "$root_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
        rm -f -- "$root_link"
      fi
    fi
    return "$rc"
  }
  trap cleanup_command_package RETURN
  tdvp_buildroot_install "$output" "$install_root" "${install_options[@]}" \
    --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
    --enable "$config_symbol" "${disable_options[@]}" \
    "${make_variable_options[@]}" --target "$buildroot_package"
  # Keep generated payloads on a POSIX filesystem. The feed repository is
  # often a Windows drvfs mount where every copied file looks executable;
  # using a symlink lets build-ipk preserve the target's 0755/0644 modes.
  if [[ -L "$root_link" ]]; then
    previous_payload=$(readlink -f -- "$root_link" 2>/dev/null || true)
    if [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]]; then
      rm -rf -- "$previous_payload"
    fi
  fi
  rm -rf -- "$root_link"
  payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
  chmod 0755 -- "$payload_dir"
  ln -s -- "$payload_dir" "$root_link"
  mkdir -p -- "$payload_dir/usr/bin" \
    "$payload_dir/usr/libexec/tdvp-$(basename "$package_dir")"
  IFS=' ' read -r -a command_list <<< "$commands"
  tdvp_is_selected_command() {
    local candidate=$1 selected
    for selected in "${command_list[@]}"; do
      [[ "$selected" == "$candidate" ]] && return 0
    done
    return 1
  }
  for command in "${command_list[@]}"; do
    [[ "$command" =~ ^[A-Za-z0-9][A-Za-z0-9+._-]*$ ]] || {
      echo "invalid Buildroot command name: $command" >&2
      return 86
    }
    public_frontends[$command]=$command
  done
  # TDVP_COMMAND_FRONTEND_NAMES is a reviewed, space-delimited collection of
  # source-command=public-command mappings.  It is deliberately not inferred
  # from PATH or BusyBox: the later base-overlay audit remains the authority
  # that proves the selected public name is safe for this firmware baseline.
  if [[ -n "${TDVP_COMMAND_FRONTEND_NAMES:-}" ]]; then
    IFS=' ' read -r -a frontend_mappings <<< "$TDVP_COMMAND_FRONTEND_NAMES"
    for frontend_mapping in "${frontend_mappings[@]}"; do
      [[ "$frontend_mapping" =~ ^([A-Za-z0-9][A-Za-z0-9+._-]*)=([A-Za-z0-9][A-Za-z0-9+._-]*)$ ]] || {
        echo "invalid Buildroot command frontend mapping: $frontend_mapping" >&2
        return 87
      }
      mapping_source=${frontend_mapping%%=*}
      mapping_frontend=${frontend_mapping#*=}
      tdvp_is_selected_command "$mapping_source" || {
        echo "Buildroot command frontend mapping names an unselected command: $mapping_source" >&2
        return 88
      }
      [[ -z "${explicit_frontends[$mapping_source]:-}" ]] || {
        echo "Buildroot command frontend mapping repeats command: $mapping_source" >&2
        return 89
      }
      explicit_frontends[$mapping_source]=1
      public_frontends[$mapping_source]=$mapping_frontend
    done
  fi
  for command in "${command_list[@]}"; do
    frontend_name=${public_frontends[$command]}
    [[ -z "${frontend_owners[$frontend_name]:-}" ]] || {
      echo "Buildroot command frontend is claimed twice: $frontend_name" >&2
      return 90
    }
    frontend_owners[$frontend_name]=$command
  done
  for command in "${command_list[@]}"; do
    source=
    # Prefer ordinary command paths exactly as before.  Some Buildroot
    # maintenance utilities intentionally install only below sbin; fall back
    # to those locations so the recipe can relocate their reviewed ELF into
    # its private libexec namespace without claiming the original path.
    for candidate in "/usr/bin/$command" "/bin/$command" "/usr/sbin/$command" "/sbin/$command"; do
      if [[ -x "$install_root$candidate" ]]; then source=$install_root$candidate; break; fi
    done
    [[ -n "$source" ]] || { echo "$buildroot_package target install omitted command: $command" >&2; return 81; }
    destination="$payload_dir/usr/libexec/tdvp-$(basename "$package_dir")/$command"
    # Preserve a simple relative alias only when its target is another command
    # explicitly selected for this same private directory. This keeps gawk's
    # `awk -> gawk` relationship and avoids copying a second large ELF, while
    # never retaining a link that could escape to a firmware path or PATH lookup.
    if [[ -L "$source" ]]; then
      link_target=$(readlink -- "$source")
      if [[ "$link_target" != */* && "$link_target" != '.' && "$link_target" != '..' ]] && \
         tdvp_is_selected_command "$link_target"; then
        ln -s -- "$link_target" "$destination"
      else
        install -Dm 0755 "$source" "$destination"
      fi
    else
      install -Dm 0755 "$source" "$destination"
    fi
    if [[ ! -L "$destination" ]]; then
      tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$destination"
    fi
    frontend_name=${public_frontends[$command]}
    cat >"$payload_dir/usr/bin/$frontend_name" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-$(basename "$package_dir")/$command "\$@"
EOF
    chmod 0755 "$payload_dir/usr/bin/$frontend_name"
  done
  # An application may carry data that is inseparable from the selected
  # command's normal operation, such as file(1)'s compiled magic database.
  # Recipes name exact absolute target files here; no directory or glob copy
  # is allowed, so source extraction remains reviewable.
  if [[ $# -ge 8 && -n "$8" ]]; then
    IFS=' ' read -r -a asset_list <<< "$8"
    for asset in "${asset_list[@]}"; do
      [[ "$asset" == /* && "$asset" != */../* && "$asset" != ../* && "$asset" != */.. ]] || {
        echo "command-package runtime data path must be an absolute clean file path: $asset" >&2
        return 82
      }
      source_asset="$install_root$asset"
      [[ -f "$source_asset" && ! -L "$source_asset" ]] || {
        echo "$buildroot_package target install omitted runtime data: $asset" >&2
        return 83
      }
      destination_asset="$payload_dir$asset"
      install -Dm 0644 "$source_asset" "$destination_asset"
    done
  fi
  payload_ready=1
  echo "$(basename "$package_dir") payload ready: $payload_dir"
}
