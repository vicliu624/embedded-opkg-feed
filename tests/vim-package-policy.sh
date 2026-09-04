#!/usr/bin/env bash
# Keep terminal Vim, its r8/r9 package split, and pure-plugin boundary explicit.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

expect_line() {
  local pattern=$1 path=$2 normalized
  # The repository is also validated from WSL worktrees whose Git settings can
  # materialise tracked text with CRLF. Policy is about the committed logical
  # line, not the local checkout's line ending.
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing required Vim policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='vim-runtime'$" "$repo_root/packages/vim-runtime/package.env"
expect_line "^VERSION='9\\.1\\.0145-1'$" "$repo_root/packages/vim-runtime/package.env"
expect_line "^SOURCE_REVISION='062141b1a70cf5364e6983ec901282e0111745c1'$" "$repo_root/packages/vim-runtime/package.env"
test -f "$repo_root/packages/vim-runtime/source.lock"
expect_line "^PACKAGE='vim'$" "$repo_root/packages/vim/package.env"
test -f "$repo_root/packages/vim/source.lock"
expect_line "^PACKAGE_DEPENDS='vim-runtime \\(= 9\\.1\\.0145-1\\), vim-plugin-repeat \\(= 1\\.2-1\\), vim-plugin-surround \\(= 2\\.2-1\\), vim-plugin-commentary \\(= 1\\.3-1\\), vim-plugin-sleuth \\(= 2\\.0-1\\)'$" "$repo_root/packages/vim/package.env"
expect_line "^set number$" "$repo_root/packages/vim/vimrc"
expect_line "^set cursorline$" "$repo_root/packages/vim/vimrc"
expect_line "^set laststatus=2$" "$repo_root/packages/vim/vimrc"
expect_line "^set mouse=$" "$repo_root/packages/vim/vimrc"
expect_line "^set scrolloff=3$" "$repo_root/packages/vim/vimrc"
expect_line "^set nowrap$" "$repo_root/packages/vim/vimrc"
expect_line "^grep -Fqx 'VIM_VERSION = 9\\.1\\.0145'" "$repo_root/packages/vim-runtime/build.sh"
expect_line "tdvp_prepare_locked_buildroot_download" "$repo_root/packages/vim-runtime/build.sh"
expect_line "offline-download-dir" "$repo_root/packages/vim-runtime/build.sh"
expect_line "tdvp_remove_elf_runtime_search_paths" "$repo_root/packages/vim/build.sh"
expect_line "install -d -m 0755.*payload_dir/usr/bin" "$repo_root/packages/vim/build.sh"
expect_line "pure Vim runtime plugin" "$repo_root/support/vim-plugin-build.sh"
expect_line "dedicated riscv64 recipe" "$repo_root/support/vim-plugin-build.sh"

for plugin in repeat surround commentary sleuth; do
  env_file="$repo_root/packages/vim-plugin-$plugin/package.env"
  expect_line "^PACKAGE='vim-plugin-$plugin'$" "$env_file"
  expect_line "^PACKAGE_KIND='runtime'$" "$env_file"
  expect_line "^PACKAGE_RELEASES='r8 r9 r10'$" "$env_file"
  expect_line "^SOURCE_REVISION='[0-9a-f]{40}'$" "$env_file"
  expect_line "^SOURCE_ARCHIVE_SHA256='[0-9a-f]{64}'$" "$env_file"
  test -f "$repo_root/packages/vim-plugin-$plugin/source.lock"
done

expect_line "^PACKAGE='vim-plugin-gitgutter'$" "$repo_root/packages/vim-plugin-gitgutter/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$repo_root/packages/vim-plugin-gitgutter/package.env"
expect_line "^PACKAGE_DEPENDS='vim-runtime \(= 9\.1\.0145-1\), git \(= 2\.48\.1-1\)'$" "$repo_root/packages/vim-plugin-gitgutter/package.env"
expect_line "^UPSTREAM_LICENSE='MIT'$" "$repo_root/packages/vim-plugin-gitgutter/source.lock"

# r8 is a complete immutable catalogue, not a Vim-only delta over r7.
for package in audacious-core audacious-plugins audacious libmgba sdl2 sdl2-ttf tdvp-gba tdvp-mpv tdvp-netsurf; do
  expect_line "^PACKAGE_RELEASES=.*\\br8\\b" "$repo_root/packages/$package/package.env"
done

echo 'Vim r8/r9/r10 package, touch/keyboard defaults, and pure-plugin policy: PASS'
