#!/usr/bin/env bash
# Verify the Audacious split and TDVP K230 touch-layout policy without a
# native RISC-V Buildroot output. The candidate workflow does the target build.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

expect_line() {
  local pattern=$1
  local path=$2
  tr -d '\r' <"$path" | grep -Eq -- "$pattern" || {
    echo "missing required policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_fixed_line() {
  local expected=$1
  local path=$2
  tr -d '\r' <"$path" | grep -Fqx -- "$expected" || {
    echo "missing required policy entry in $path: $expected" >&2
    exit 1
  }
}

expect_exactly_once() {
  local text=$1
  local path=$2
  local count
  count=$(grep -Fc -- "$text" "$path")
  [[ "$count" -eq 1 ]] || {
    echo "expected exactly one occurrence in $path: $text (found $count)" >&2
    exit 1
  }
}

core_env="$repo_root/packages/audacious-core/package.env"
plugins_env="$repo_root/packages/audacious-plugins/package.env"
app_env="$repo_root/packages/audacious/package.env"
core_buildroot_recipe="$repo_root/support/audacious-buildroot/tdvp-audacious.mk"
plugins_buildroot_recipe="$repo_root/support/audacious-buildroot/tdvp-audacious-plugins.mk"
plugins_buildroot_hash="$repo_root/support/audacious-buildroot/tdvp-audacious-plugins.hash"
layout_config="$repo_root/packages/audacious/tdvp-k230-default.conf"
owner_map="$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

expect_line "^PACKAGE='audacious-core'$" "$core_env"
expect_line "^PACKAGE_KIND='shared-library'$" "$core_env"
expect_line "^VERSION='4\\.6\\.1-1'$" "$core_env"
expect_line "^PACKAGE='audacious-plugins'$" "$plugins_env"
expect_line "^PACKAGE_DEPENDS='audacious-core \\(= 4\\.6\\.1-1\\)'$" "$plugins_env"
expect_line "^PACKAGE='audacious'$" "$app_env"
expect_line "^PACKAGE_DEPENDS='audacious-core \\(= 4\\.6\\.1-1\\), audacious-plugins \\(= 4\\.6\\.1-1\\), hicolor-icon-theme \\(= 2025\\.02\\.1-1\\)'$" "$app_env"
expect_fixed_line 'TDVP_AUDACIOUS_VERSION = 4.6.1' "$core_buildroot_recipe"
expect_fixed_line 'TDVP_AUDACIOUS_PLUGINS_VERSION = 4.6.1' "$plugins_buildroot_recipe"
expect_fixed_line 'sha256  22e58a8a2c3f3caa9687434353618c822963cc8846cd239de36d4e8e5bd166a6  audacious-plugins-4.6.1.tar.bz2' "$plugins_buildroot_hash"
expect_line '^[[:space:]]*-Dgtkui=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dffaudio=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dalsa=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dpulse=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dqt=false \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dqtui=false \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dpipewire=false \\' "$plugins_buildroot_recipe"

# Buildroot derives package identity from a .mk filename. Each file must
# register exactly its own package, otherwise the second meson-package
# evaluation is identified as tdvp-audacious and candidate builds fail.
expect_exactly_once '$(eval $(meson-package))' "$core_buildroot_recipe"
expect_exactly_once '$(eval $(meson-package))' "$plugins_buildroot_recipe"
if grep -Fq 'TDVP_AUDACIOUS_PLUGINS_' "$core_buildroot_recipe"; then
  echo 'Audacious plugins must use their own Buildroot recipe file' >&2
  exit 1
fi

# 1232 x 568 is the physical landscape display. The fallback deliberately
# leaves room for compositor decoration/panel; normal startup is maximized.
expect_fixed_line 'player_width=1184' "$layout_config"
expect_fixed_line 'player_height=480' "$layout_config"
expect_fixed_line 'player_maximized=TRUE' "$layout_config"
expect_fixed_line 'infoarea_show_vis=FALSE' "$layout_config"
expect_fixed_line 'statusbar_visible=FALSE' "$layout_config"

for soname in libaudcore.so.6 libaudtag.so.4 libaudgui.so.7; do
  count=$(tr -d '\r' <"$owner_map" | grep -Ec "^${soname//./\\.}\\|audacious-core\\|4\\.6\\.1-1$")
  [[ "$count" -eq 1 ]] || {
    echo "expected exactly one Audacious runtime owner for $soname, found $count" >&2
    exit 1
  }
done

echo 'Audacious split and TDVP K230 layout policy: PASS'
