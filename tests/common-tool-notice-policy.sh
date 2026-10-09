#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for helper in buildroot-command-package.sh buildroot-archive-library.sh; do
  grep -Fq 'tdvp_copy_installed_notices "$install_root" "$buildroot_package" "$payload_dir" "$(basename "$package_dir")"' "$repo_root/support/$helper"
  load_line=$(grep -n 'source .*package-notice-library.sh' "$repo_root/support/$helper" | cut -d: -f1)
  trap_line=$(grep -n 'trap .* RETURN' "$repo_root/support/$helper" | head -n1 | cut -d: -f1)
  [[ "$load_line" -lt "$trap_line" ]]
done
grep -Fq 'COPYING COPYING.txt COPYING.LESSER LICENSE LICENSE.txt LICENCE LICENCE.txt COPYRIGHT NOTICE PATENTS' "$repo_root/support/published-sdk-build.sh"
python3 "$repo_root/tests/source-notice-filenames.py"
grep -Fq '"$source_dir/COPYING" "$payload_dir/usr/share/licenses/git-runtime/COPYING"' "$repo_root/packages/git-runtime/build.sh"
grep -Fq '"$stage_root/usr/share/licenses/git/COPYING" "$payload_dir/usr/share/licenses/git/COPYING"' "$repo_root/packages/git/build.sh"
grep -Fq '"$source_dir/LICENCE" "$payload_dir/usr/share/licenses/openssh-client/LICENCE"' "$repo_root/packages/openssh-client/build.sh"
echo 'Common tool notice projection policy: PASS'
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
source "$repo_root/support/package-notice-library.sh"
mkdir -p "$work/install/usr/share/licenses/file"
printf 'Fixture upstream bytes\r\n' > "$work/install/usr/share/licenses/file/COPYING"
tdvp_copy_installed_notices "$work/install" file "$work/payload" libmagic
cmp "$work/install/usr/share/licenses/file/COPYING" "$work/payload/usr/share/licenses/libmagic/COPYING"
[[ ! -e "$work/payload/usr/share/licenses/file" ]]
ln -s /outside "$work/install/usr/share/licenses/file/NOTICE"
if tdvp_copy_installed_notices "$work/install" file "$work/rejected" libmagic; then
  echo 'notice projection accepted symlink' >&2; exit 1
fi
[[ ! -e "$work/rejected" ]]
echo 'Common tool notice projection runtime: PASS namespace, original bytes and link rejection'
