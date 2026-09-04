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

expect_contains() {
  local expected=$1
  local path=$2
  grep -Fq -- "$expected" "$path" || {
    echo "missing required policy fragment in $path: $expected" >&2
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

expect_recipe_directory_identity() {
  local recipe=$1
  local package_dir
  local recipe_name
  package_dir=$(basename -- "$(dirname -- "$recipe")")
  recipe_name=$(basename -- "${recipe%.mk}")
  [[ "$package_dir" == "$recipe_name" ]] || {
    echo "Buildroot recipe must live in its own matching package directory: $recipe" >&2
    exit 1
  }
}

core_env="$repo_root/packages/audacious-core/package.env"
plugins_env="$repo_root/packages/audacious-plugins/package.env"
app_env="$repo_root/packages/audacious/package.env"
core_build_script="$repo_root/packages/audacious-core/build.sh"
plugins_build_script="$repo_root/packages/audacious-plugins/build.sh"
buildroot_support_dir="$repo_root/support/audacious-buildroot"
core_buildroot_dir="$buildroot_support_dir/tdvp-audacious"
plugins_buildroot_dir="$buildroot_support_dir/tdvp-audacious-plugins"
core_buildroot_recipe="$core_buildroot_dir/tdvp-audacious.mk"
plugins_buildroot_recipe="$plugins_buildroot_dir/tdvp-audacious-plugins.mk"
core_buildroot_config="$core_buildroot_dir/Config.in"
plugins_buildroot_config="$plugins_buildroot_dir/Config.in"
plugins_buildroot_hash="$plugins_buildroot_dir/tdvp-audacious-plugins.hash"
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
expect_fixed_line 'TDVP_AUDACIOUS_INSTALL_STAGING = YES' "$core_buildroot_recipe"
expect_fixed_line 'TDVP_AUDACIOUS_PLUGINS_VERSION = 4.6.1' "$plugins_buildroot_recipe"
expect_fixed_line 'sha256  22e58a8a2c3f3caa9687434353618c822963cc8846cd239de36d4e8e5bd166a6  audacious-plugins-4.6.1.tar.bz2' "$plugins_buildroot_hash"
expect_line '^config BR2_PACKAGE_TDVP_AUDACIOUS$' "$core_buildroot_config"
expect_line '^config BR2_PACKAGE_TDVP_AUDACIOUS_PLUGINS$' "$plugins_buildroot_config"
expect_line '^[[:space:]]*-Dgtkui=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dffaudio=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dalsa=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dpulse=true \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dqt=false \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dqtui=false \\' "$plugins_buildroot_recipe"
expect_line '^[[:space:]]*-Dpipewire=false \\' "$plugins_buildroot_recipe"

# Buildroot derives package identity from its package directory. Each staged
# directory must register exactly one package, otherwise the plugin evaluation
# is identified as tdvp-audacious and candidate builds fail.
expect_exactly_once '$(eval $(meson-package))' "$core_buildroot_recipe"
expect_exactly_once '$(eval $(meson-package))' "$plugins_buildroot_recipe"
expect_recipe_directory_identity "$core_buildroot_recipe"
expect_recipe_directory_identity "$plugins_buildroot_recipe"
if grep -Fq 'TDVP_AUDACIOUS_PLUGINS_' "$core_buildroot_recipe"; then
  echo 'Audacious plugins must use their own Buildroot recipe file' >&2
  exit 1
fi
if [[ -e "$buildroot_support_dir/Config.in" || -e "$buildroot_support_dir/tdvp-audacious.mk" || -e "$buildroot_support_dir/tdvp-audacious-plugins.mk" ]]; then
  echo 'Audacious Buildroot recipes must be staged from separate package directories' >&2
  exit 1
fi
expect_contains 'package/tdvp-audacious/Config.in' "$core_build_script"
expect_contains 'package/tdvp-audacious/Config.in' "$plugins_build_script"
expect_contains 'package/tdvp-audacious-plugins/Config.in' "$plugins_build_script"
for build_script in "$core_build_script" "$plugins_build_script"; do
  expect_contains 'buildroot_staging_source="$build_output/host/riscv64-buildroot-linux-gnu/sysroot"' "$build_script"
  expect_contains 'buildroot_staging_root=$(mktemp -d)' "$build_script"
  expect_contains 'cp -a --reflink=auto "$buildroot_staging_source/." "$buildroot_staging_root/"' "$build_script"
  expect_contains 'STAGING_DIR="$buildroot_staging_root" make -C "$build_output"' "$build_script"
  expect_contains 'rm -rf -- "$install_root" "$buildroot_staging_root" "$download_dir"' "$build_script"
  expect_contains 'config_old_backup=' "$build_script"
  expect_contains 'cp --preserve=mode,timestamps -- "$config_backup" "$build_output/.config" || rc=98' "$build_script"
  expect_contains 'cp --preserve=mode,timestamps -- "$config_old_backup" "$build_output/.config.old" || rc=100' "$build_script"
  if grep -Fq 'make -C "$build_output" olddefconfig || rc=98' "$build_script"; then
    echo 'Audacious cleanup must not normalize the restored SDK config' >&2
    exit 1
  fi
done
expect_contains 'tdvp-audacious-dirclean' "$plugins_build_script"
expect_contains 'test -s "$buildroot_staging_root/usr/lib/pkgconfig/audacious.pc"' "$core_build_script"
expect_contains 'test -s "$buildroot_staging_root/usr/lib/pkgconfig/audacious.pc"' "$plugins_build_script"

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
