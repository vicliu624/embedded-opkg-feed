#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in vim-plugin-commentary vim-plugin-repeat vim-plugin-surround vim-plugin-sleuth; do
  grep -Fqx "VIM_PLUGIN_SHARED_LICENSE_ARCHIVE='vim-9.1.0145.tar.gz'" "$repo_root/packages/$package/package.env"
  grep -Fqx "SOURCE_ARTIFACT_2_SHA256='0056537cb57190aa41c12ba6c2ad04ce10e7f714cde4c1fe7193a37e1c44db46'" "$repo_root/packages/$package/source.lock"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$repo_root/packages/$package"
done
grep -Fqx "VIM_PLUGIN_LICENSE_DOCUMENT='doc/sleuth.txt'" "$repo_root/packages/vim-plugin-sleuth/package.env"
grep -Fq 'tdvp_source_archive_locked_file "$package_dir" "$VIM_PLUGIN_SHARED_LICENSE_ARCHIVE"' "$repo_root/support/vim-plugin-build.sh"
grep -Fq 'usr/share/licenses/$PACKAGE/Vim-LICENSE' "$repo_root/support/vim-plugin-build.sh"
grep -Fq 'usr/share/licenses/$PACKAGE/UPSTREAM-NOTICE.txt' "$repo_root/support/vim-plugin-build.sh"
echo 'Vim plugin notices: PASS locked common terms, upstream documentation and no native dependency'
