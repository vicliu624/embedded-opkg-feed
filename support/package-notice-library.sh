#!/usr/bin/env bash
# Preserve an installed component's notices in its final IPK owner's namespace.
tdvp_copy_installed_notices() {
  local install_root=$1 component=$2 payload_root=$3 package=$4
  local source_dir="$install_root/usr/share/licenses/$component"
  [[ "$component" =~ ^[A-Za-z0-9_+.-]+$ && "$component" != . && "$component" != .. &&
     "$package" =~ ^[a-z0-9+.-]+$ && "$package" != . && "$package" != .. ]] || {
    echo 'invalid notice component/package namespace' >&2; return 65;
  }
  [[ ! -L "$source_dir" ]] || { echo 'unsafe notice directory link' >&2; return 65; }
  [[ -d "$source_dir" ]] || return 0
  [[ -z "$(find "$source_dir" -type l -print -quit)" ]] || {
    echo 'unsafe installed notice link' >&2; return 65;
  }
  mkdir -p -- "$payload_root/usr/share/licenses/$package"
  cp -a -- "$source_dir/." "$payload_root/usr/share/licenses/$package/"
}
