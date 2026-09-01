#!/usr/bin/env bash
# Build one ordinary command suite from the locked Buildroot tree.  The suite
# is installed below /usr/libexec/tdvp-<package>; small /usr/bin frontends
# retain standard command names without replacing a BusyBox executable in the
# immutable firmware.
set -Eeuo pipefail
IFS=$'\n\t'

tdvp_buildroot_command_package() {
  local package_dir=$1 sdk_root=$2 configured_output=$3 config_symbol=$4
  local buildroot_package=$5 source_line=$6 commands=$7
  local output tree install_root payload_dir command source
  local -a command_list=()
  # shellcheck source=buildroot-feed-session.sh
  source "$package_dir/../../support/buildroot-feed-session.sh"
  output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
  tree=$(tdvp_buildroot_tree_from_output "$output")
  tdvp_assert_buildroot_2025_02_1 "$tree"
  grep -Fqx "$source_line" "$tree/package/$buildroot_package/${buildroot_package}.mk" || {
    echo "locked Buildroot source differs from reviewed $buildroot_package recipe" >&2
    return 80
  }
  install_root=$(mktemp -d)
  cleanup_command_package() { rm -rf -- "$install_root"; }
  trap cleanup_command_package RETURN
  tdvp_buildroot_install "$output" "$install_root" \
    --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
    --enable "$config_symbol" --target "$buildroot_package"
  payload_dir="$package_dir/root"
  rm -rf -- "$payload_dir"
  mkdir -p -- "$payload_dir/usr/bin" \
    "$payload_dir/usr/libexec/tdvp-$(basename "$package_dir")"
  IFS=' ' read -r -a command_list <<< "$commands"
  for command in "${command_list[@]}"; do
    source=
    for candidate in "/usr/bin/$command" "/bin/$command"; do
      if [[ -x "$install_root$candidate" ]]; then source=$install_root$candidate; break; fi
    done
    [[ -n "$source" ]] || { echo "$buildroot_package target install omitted command: $command" >&2; return 81; }
    install -Dm 0755 "$source" "$payload_dir/usr/libexec/tdvp-$(basename "$package_dir")/$command"
    cat >"$payload_dir/usr/bin/$command" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-$(basename "$package_dir")/$command "\$@"
EOF
    chmod 0755 "$payload_dir/usr/bin/$command"
  done
  echo "$(basename "$package_dir") payload ready: $payload_dir"
}
