#!/usr/bin/env bash
# psmisc is a version-delta, command-only candidate. Keep the device ABI and
# CI execution boundary explicit before scarce GitHub Actions capacity is used.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/psmisc"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='psmisc'" "$package_dir/package.env"
grep -Fqx "VERSION='23.7-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS='libncursesw (= 6.4-20230603-1)'" "$package_dir/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS='libncursesw'" "$package_dir/package.env"
grep -Fqx 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "SOURCE_TYPE='release-tarball'" "$package_dir/source.lock"
grep -Fqx "UPSTREAM_VERSION='23.7'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_FILE='psmisc-23.7.tar.xz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='58c55d9c1402474065adae669511c191de374b0871eec781239ab400b907c327'" "$package_dir/source.lock"
grep -Fqx 'sha256  58c55d9c1402474065adae669511c191de374b0871eec781239ab400b907c327  psmisc-23.7.tar.xz' "$package_dir/buildroot.hash.override"
grep -Fq "TDVP_COMMAND_BUILDROOT_HASH_OVERRIDE_FILE='buildroot.hash.override'" "$package_dir/build.sh"
grep -Fq 'PSMISC_VERSION=23.7' "$package_dir/build.sh"
grep -Fq "BR2_PACKAGE_PSMISC psmisc 'PSMISC_VERSION = 23.5'" "$package_dir/build.sh"
grep -Fq 'fuser=tdvp-fuser killall=tdvp-killall pslog=tdvp-pslog prtstat=tdvp-prtstat pstree=tdvp-pstree' "$package_dir/build.sh"
grep -Fq "'fuser killall pslog prtstat pstree'" "$package_dir/build.sh"
if sed '/^[[:space:]]*#/d' "$package_dir/build.sh" | grep -Eq '/usr/bin/(fuser|killall|pslog|prtstat|pstree)|peekfd|apt|dpkg|debian'; then
  echo 'psmisc recipe must keep only private approved commands and no Debian binary input' >&2
  exit 1
fi
if grep -R -n -E 'BR_NO_CHECK_HASH|NO_CHECK_HASH|SKIP.*HASH|DISABLE.*HASH' "$package_dir"; then
  echo 'psmisc recipe must retain Buildroot hash verification' >&2
  exit 1
fi

grep -Fq 'process-inspection-tools)' "$workflow"
grep -Fq 'package_args=(--package psmisc)' "$workflow"
grep -Fq 'expected_packages=(psmisc)' "$workflow"
grep -Fq 'bash ./tests/psmisc-package-policy.sh' "$workflow"

echo 'locked private psmisc policy: PASS'
