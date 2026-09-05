#!/usr/bin/env bash
# Keep inotify-tools a static, private command pair rather than a library ABI.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/inotify-tools"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing inotify-tools policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='inotify-tools'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]20[.]2[.]2-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='inotify-tools'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='inotify-tools-3[.]20[.]2[.]2[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='c5b018567814ea555d716f518b6e3ae243c733f7bd3e8585d81748a6da286f3c'$" "$package_dir/source.lock"

grep -Fq 'INOTIFY_TOOLS_CONF_OPTS=--disable-shared --enable-static --enable-static-binary --disable-doxygen' "$package_dir/build.sh"
grep -Fq 'inotifywait=tdvp-inotify-wait' "$package_dir/build.sh"
grep -Fq 'inotifywatch=tdvp-inotify-watch' "$package_dir/build.sh"
grep -Fq "'inotifywait inotifywatch'" "$package_dir/build.sh"
if grep -Eq '/usr/bin/inotify(wait|watch)|/usr/sbin/inotify|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'inotify-tools build must not publish ordinary paths or import Debian inputs' >&2
  exit 1
fi

grep -Fq 'filesystem-event-tools)' "$workflow"
grep -Fq 'package_args=(--package inotify-tools)' "$workflow"
grep -Fq 'expected_packages=(inotify-tools)' "$workflow"
grep -Fq 'bash ./tests/inotify-tools-package-policy.sh' "$workflow"

echo 'locked static inotify-tools policy: PASS'
