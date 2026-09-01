#!/usr/bin/env bash
# Verify the Audacious split and the TDVP K230 touch-layout policy without
# needing a native RISC-V Buildroot output.  The candidate-build workflow does
# the actual target compile; this keeps simple metadata/config regressions out
# of every pull request as well.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

expect_line() {
  local pattern=$1
  local path=$2
  grep -Eq -- "$pattern" "$path" || {
    echo "missing required policy entry in $path: $pattern" >&2
    exit 1
  }
}

core_env="$repo_root/packages/audacious-core/package.env"
plugins_env="$repo_root/packages/audacious-plugins/package.env"
app_env="$repo_root/packages/audacious/package.env"
buildroot_recipe="$repo_root/support/audacious-buildroot/tdvp-audacious.mk"
layout_config="$repo_root/packages/audacious/tdvp-k230-default.conf"
owner_map="$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

expect_line "^PACKAGE='audacious-core'$" "$core_env"
expect_line "^PACKAGE_KIND='shared-library'$" "$core_env"
expect_line "^VERSION='4\\.6\\.1-1'$" "$core_env"
expect_line "^PACKAGE='audacious-plugins'$" "$plugins_env"
expect_line "^PACKAGE_DEPENDS='audacious-core \\(= 4\\.6\\.1-1\\)'$" "$plugins_env"
expect_line "^PACKAGE='audacious'$" "$app_env"
expect_line "^PACKAGE_DEPENDS='audacious-core \\(= 4\\.6\\.1-1\\), audacious-plugins \\(= 4\\.6\\.1-1\\), hicolor-icon-theme \\(= 2025\\.02\\.1-1\\)'$" "$app_env"
expect_line '^TDVP_AUDACIOUS_VERSION = 4\.6\.1$' "$buildroot_recipe"
expect_line '^TDVP_AUDACIOUS_PLUGINS_VERSION = 4\.6\.1$' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dgtkui=true \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dffaudio=true \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dalsa=true \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dpulse=true \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dqt=false \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dqtui=false \\' "$buildroot_recipe"
expect_line '^[[:space:]]*-Dpipewire=false \\' "$buildroot_recipe"

# 1232 x 568 is the physical landscape display.  The fallback deliberately
# leaves room for compositor decoration/panel; normal startup is maximized.
expect_line '^player_width=1184$' "$layout_config"
expect_line '^player_height=480$' "$layout_config"
expect_line '^player_maximized=TRUE$' "$layout_config"
expect_line '^infoarea_show_vis=FALSE$' "$layout_config"
expect_line '^statusbar_visible=FALSE$' "$layout_config"

for soname in libaudcore.so.6 libaudtag.so.4 libaudgui.so.7; do
  count=$(grep -Ec "^${soname//./\\.}\\|audacious-core\\|4\\.6\\.1-1$" "$owner_map")
  [[ "$count" -eq 1 ]] || {
    echo "expected exactly one Audacious runtime owner for $soname, found $count" >&2
    exit 1
  }
done

echo 'Audacious split and TDVP K230 layout policy: PASS'
