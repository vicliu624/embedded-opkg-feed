#!/usr/bin/env bash
# Exercise build-all's strict source gate end-to-end with a metadata-only
# installation profile.  Such a profile may be exempt, but a package cannot
# silently omit both a provenance record and that explicit exemption.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

fixture_root="$work_root/feed"
mkdir -p -- \
  "$fixture_root/scripts" \
  "$fixture_root/support" \
  "$fixture_root/platforms/fixture" \
  "$fixture_root/packages/fixture-profile" \
  "$fixture_root/packages/fixture-consumer"

for script in \
  build-all.sh \
  build-ipk.sh \
  feed-platform.sh \
  fetch-source-cache.sh \
  make-index.sh \
  verify-feed.sh \
  verify-source-lock.sh; do
  cp -- "$repo_root/scripts/$script" "$fixture_root/scripts/$script"
done

# build-ipk sources the shared ELF policy helper even when this fixture has no
# target ELF. Keep the miniature repository structurally faithful so the test
# reaches the source-lock gate it is intended to exercise.
cp -- "$repo_root/support/elf-runtime-policy.sh" \
  "$fixture_root/support/elf-runtime-policy.sh"

printf '%s\n' \
  "PLATFORM_SLUG='fixture'" \
  "PLATFORM_ID='fixture'" \
  "ARCH='riscv64'" \
  "ABI_PACKAGE='fixture-platform-abi'" \
  "ABI_VERSION='1'" \
  "DEFAULT_FEED_RELEASE='r1'" \
  >"$fixture_root/platforms/fixture/platform.env"

package_dir="$fixture_root/packages/fixture-profile"
printf '%s\n' \
  "PACKAGE='fixture-profile'" \
  "VERSION='1.0-1'" \
  "DESCRIPTION='Fixture metadata-only installation profile'" \
  "MAINTAINER='TDVP test <tests@example.invalid>'" \
  "SUPPORTED_PLATFORMS='fixture'" \
  "PACKAGE_KIND='application'" \
  "PACKAGE_RELEASES='r1'" \
  "PACKAGE_AUTO_RUNTIME_DEPENDS=0" \
  "PACKAGE_BASE_OVERLAY='deny'" \
  "SOURCE_LOCK_EXEMPT_REASON='Fixture installation profile contains only TDVP-owned metadata and documentation.'" \
  >"$package_dir/package.env"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -Eeuo pipefail' \
  "[[ \$# -eq 4 && \$1 == '--platform' && \$2 == 'fixture' && \$3 == '--sdk-root' ]] || exit 64" \
  'package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)' \
  'payload_dir=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-command-payload.XXXXXX")' \
  'printf "%s\n" "$payload_dir" >"$package_dir/generated-payload-path"' \
  'rm -rf -- "$package_dir/root"' \
  'ln -s -- "$payload_dir" "$package_dir/root"' \
  'mkdir -p -- "$payload_dir/usr/share/doc/fixture-profile"' \
  "printf '%s\\n' 'Fixture profile documentation.' >\"\$payload_dir/usr/share/doc/fixture-profile/README\"" \
  'mkdir -p -- "$TDVP_FEED_STAGING_ROOT/usr/include"' \
  "printf '%s\\n' 'fixture profile build interface' >\"\$TDVP_FEED_STAGING_ROOT/usr/include/fixture-profile.h\"" \
  >"$package_dir/build.sh"
chmod +x -- "$package_dir/build.sh"

# A second recipe consumes a header emitted into build-all's disposable
# staging root. It exercises the incremental hand-off path: a later batch may
# import that staging root and provide the first recipe through an attested
# IPK, without executing its build hook again.
printf '%s\n' \
  "PACKAGE='fixture-consumer'" \
  "VERSION='1.0-1'" \
  "DESCRIPTION='Fixture staged dependency consumer'" \
  "MAINTAINER='TDVP test <tests@example.invalid>'" \
  "SUPPORTED_PLATFORMS='fixture'" \
  "PACKAGE_KIND='application'" \
  "PACKAGE_RELEASES='r1'" \
  "PACKAGE_BUILD_DEPENDS='fixture-profile'" \
  "PACKAGE_AUTO_RUNTIME_DEPENDS=0" \
  "PACKAGE_BASE_OVERLAY='deny'" \
  "SOURCE_LOCK_EXEMPT_REASON='Fixture consumer uses only a previous build staging artifact.'" \
  >"$fixture_root/packages/fixture-consumer/package.env"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -Eeuo pipefail' \
  "[[ \$# -eq 4 && \$1 == '--platform' && \$2 == 'fixture' && \$3 == '--sdk-root' ]] || exit 64" \
  'test -s "$TDVP_FEED_STAGING_ROOT/usr/include/fixture-profile.h"' \
  'package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)' \
  'payload_dir=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-command-payload.XXXXXX")' \
  'rm -rf -- "$package_dir/root"' \
  'ln -s -- "$payload_dir" "$package_dir/root"' \
  'mkdir -p -- "$payload_dir/usr/share/doc/fixture-consumer"' \
  "printf '%s\\n' 'Fixture consumer documentation.' >\"\$payload_dir/usr/share/doc/fixture-consumer/README\"" \
  >"$fixture_root/packages/fixture-consumer/build.sh"
chmod +x -- "$fixture_root/packages/fixture-consumer/build.sh"

successful_output="$work_root/output-success"
bash "$fixture_root/scripts/build-all.sh" \
  --platform fixture \
  --release r1 \
  --output "$successful_output" \
  --require-source-locks
feed_dir="$successful_output/fixture/riscv64"
test -s "$feed_dir/fixture-profile_1.0-1_riscv64.ipk"
test -s "$feed_dir/Packages"
test -s "$feed_dir/Packages.gz"
grep -Fqx 'Package: fixture-profile' "$feed_dir/Packages"
grep -Fqx 'Depends: fixture-platform-abi (= 1)' "$feed_dir/Packages"
test ! -e "$package_dir/root"
test ! -e "$(cat "$package_dir/generated-payload-path")"
grep -Fq 'discard_generated_payload' "$fixture_root/scripts/build-all.sh"
grep -Fq 'TDVP_SOURCE_CACHE_OFFLINE="$offline_source_cache"' "$fixture_root/scripts/build-all.sh"

# A repeated --package is the batch boundary used by the K230 candidate CI.
# The selected root must remain independently buildable instead of silently
# falling back to every recipe in the repository.
selected_output="$work_root/output-selected"
bash "$fixture_root/scripts/build-all.sh" \
  --platform fixture \
  --release r1 \
  --output "$selected_output" \
  --require-source-locks \
  --package fixture-profile
selected_feed_dir="$selected_output/fixture/riscv64"
test -s "$selected_feed_dir/fixture-profile_1.0-1_riscv64.ipk"
test -s "$selected_feed_dir/Packages"
grep -Fqx 'Package: fixture-profile' "$selected_feed_dir/Packages"
grep -Fq 'select_package_closure()' "$fixture_root/scripts/build-all.sh"
grep -Fq 'emit_runtime_dependency_names()' "$fixture_root/scripts/build-all.sh"
grep -Fq 'target_catalogue_has_package()' "$fixture_root/scripts/build-all.sh"

# An independent follow-up batch imports only the prior recipe's exported
# staging projection and its already-built IPK. Its declared build dependency
# must be satisfied from those verified inputs rather than rebuilt.
staging_export="$work_root/staging-export"
state_output="$work_root/output-state"
bash "$fixture_root/scripts/build-all.sh" \
  --platform fixture \
  --release r1 \
  --output "$state_output" \
  --require-source-locks \
  --export-staging "$staging_export" \
  --package fixture-profile
test -s "$staging_export/usr/include/fixture-profile.h"
test -s "$staging_export/tdvp-build-staging-manifest.tsv"
grep -Fqx $'built-package\tfixture-profile\t1.0-1' "$staging_export/tdvp-build-staging-manifest.tsv"

provided_output="$work_root/output-provided"
provided_feed="$provided_output/fixture/riscv64"
mkdir -p -- "$provided_feed"
cp -- "$state_output/fixture/riscv64/fixture-profile_1.0-1_riscv64.ipk" "$provided_feed/"
bash "$fixture_root/scripts/build-all.sh" \
  --platform fixture \
  --release r1 \
  --output "$provided_output" \
  --require-source-locks \
  --import-staging "$staging_export" \
  --provided-package fixture-profile \
  --package fixture-consumer
test -s "$provided_feed/fixture-profile_1.0-1_riscv64.ipk"
test -s "$provided_feed/fixture-consumer_1.0-1_riscv64.ipk"
grep -Fqx 'Package: fixture-profile' "$provided_feed/Packages"
grep -Fqx 'Package: fixture-consumer' "$provided_feed/Packages"
grep -Fq -- '--provided-package' "$fixture_root/scripts/build-all.sh"
grep -Fq -- '--import-staging' "$fixture_root/scripts/build-all.sh"
grep -Fq -- '--export-staging' "$fixture_root/scripts/build-all.sh"
grep -Fq 'assert_provided_package()' "$fixture_root/scripts/build-all.sh"

# The normal r1 fixture has no composable target-runtime catalogue.  Both
# incremental-runtime switches must therefore reject it rather than quietly
# producing a partial feed with no ownership evidence.
for runtime_switch in --runtime-catalog-only --reuse-runtime-catalog; do
  runtime_output="$work_root/output-${runtime_switch#--}"
  if bash "$fixture_root/scripts/build-all.sh" \
    --platform fixture \
    --release r1 \
    --output "$runtime_output" \
    "$runtime_switch" \
    >"$work_root/${runtime_switch#--}.log" 2>&1; then
    echo "build-all accepted $runtime_switch for a release without a runtime catalogue" >&2
    exit 1
  fi
  grep -Fq 'runtime-catalog options require a composable r3-or-newer release' \
    "$work_root/${runtime_switch#--}.log"
done
grep -Fq 'runtime catalogue base ready for incremental batches' \
  "$fixture_root/scripts/build-all.sh"
grep -Fq 'reusing cached target-runtime catalogue' "$fixture_root/scripts/build-all.sh"

# Removing the literal, reviewable exemption turns the same profile into an
# unprovenanced recipe.  The failure must happen before its build hook creates
# a payload, so it cannot leave a candidate artifact behind.
sed -i '/^SOURCE_LOCK_EXEMPT_REASON=/d' "$package_dir/package.env"
failed_output="$work_root/output-missing-lock"
if bash "$fixture_root/scripts/build-all.sh" \
  --platform fixture \
  --release r1 \
  --output "$failed_output" \
  --require-source-locks \
  >"$work_root/missing-lock.log" 2>&1; then
  echo 'build-all accepted a package with neither source.lock nor an exemption' >&2
  exit 1
fi
grep -Fq 'selected package has no source.lock or SOURCE_LOCK_EXEMPT_REASON' \
  "$work_root/missing-lock.log"
test ! -e "$package_dir/root"
test ! -e "$failed_output/fixture/riscv64/fixture-profile_1.0-1_riscv64.ipk"

echo 'build-all source-lock policy: PASS'
