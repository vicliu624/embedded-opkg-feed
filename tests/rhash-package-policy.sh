#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/rhash"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='rhash'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='8e7d1a8ccac0143c8fe9b68ebac67d485df119ea17a613f4038cda52f84ef52a'" "$package_dir/source.lock"
grep -Fq "TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_RHASH_BIN'" "$package_dir/build.sh"
grep -Fq 'RHASH_CONF_OPTS=--disable-gettext --disable-openssl --enable-static=librhash --enable-lib-static --disable-lib-shared' "$package_dir/build.sh"
grep -Fq 'RHASH_BUILD_TARGETS=lib-static build' "$package_dir/build.sh"
grep -Fq 'RHASH_INSTALL_TARGETS=install-lib-static' "$package_dir/build.sh"
grep -Fq 'rhash=tdvp-rhash' "$package_dir/build.sh"
grep -Fq 'checksum-tools)' "$workflow"
grep -Fq 'package_args=(--package rhash)' "$workflow"
grep -Fq 'bash ./tests/rhash-package-policy.sh' "$workflow"
echo 'locked private rhash policy: PASS'
