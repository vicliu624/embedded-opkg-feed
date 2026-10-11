#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
helper="$repo_root/support/published-sdk-build.sh"
grep -Fq 'if [[ "$source_name" == *.tar.lz ]]; then' "$helper"
grep -Fq 'tdvp_source_archive_locked_file "$package_dir" lzip-1.25.tar.gz' "$helper"
grep -Fq './configure --prefix="$work/host-tools"' "$helper"
grep -Fq 'export PATH="$work/host-tools/bin:$PATH"' "$helper"
grep -Fq 'env -u CC -u CXX -u AR -u RANLIB -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS' "$helper"
bash -n "$helper"
bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$repo_root/packages/make"
echo 'Published SDK locked host lzip policy: PASS'
