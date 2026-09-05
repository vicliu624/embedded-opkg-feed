#!/usr/bin/env bash
# Prove that the Buildroot transaction restores exact user-owned config bytes.
# This is a hermetic fixture: no firmware SDK, package source, or network is
# involved.  It deliberately makes olddefconfig rewrite .config/.config.old,
# which catches a cleanup implementation that normalizes instead of restores.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../support/buildroot-feed-session.sh
source "$repo_root/support/buildroot-feed-session.sh"

work=$(mktemp -d)
cleanup() { rm -rf -- "$work"; }
trap cleanup EXIT

tree="$work/buildroot"
output="$work/output"
install_root="$work/install-root"
mkdir -p "$tree/utils" "$output/host/bin" "$output/target" "$install_root"

cat >"$tree/Makefile" <<'EOF'
export BR2_VERSION := 2025.02.1
EOF
cat >"$tree/utils/config" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
config_file=
symbol=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --file) config_file=$2; shift 2 ;;
    --enable|--disable) symbol=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf '%s=y\n' "$symbol" >>"$config_file"
EOF
chmod 0755 "$tree/utils/config"

cat >"$output/Makefile" <<EOF
MAKEARGS := -C $tree
EOF
cat >"$output/host/bin/make" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
output=
previous=
for argument in "$@"; do
  if [[ "$previous" == '-C' ]]; then
    output=$argument
    break
  fi
  previous=$argument
done
[[ -n "$output" ]] || exit 2
printf '%s\n' "$*" >>"$output/.tdvp-make.log"
case " $* " in
  *' olddefconfig '*)
    printf 'NORMALIZED_CONFIG=y\n' >>"$output/.config"
    printf 'NORMALIZED_OLD=y\n' >"$output/.config.old"
    ;;
esac
EOF
chmod 0755 "$output/host/bin/make"

run_fixture() {
  tdvp_buildroot_install "$output" "$install_root" \
    --enable BR2_TEST_FEATURE \
    --make-variable FIXTURE_CONF_OPTS=--no-optional-feature \
    --make-variable FIXTURE_DEPENDENCIES= --target fixture
}

printf 'ORIGINAL_CONFIG=y\n' >"$output/.config"
printf 'ORIGINAL_OLD=y\n' >"$output/.config.old"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')
old_hash=$(sha256sum "$output/.config.old" | awk '{print $1}')
run_fixture
[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
[[ "$(sha256sum "$output/.config.old" | awk '{print $1}')" == "$old_hash" ]]
[[ "$(grep -Fc 'olddefconfig' "$output/.tdvp-make.log")" -eq 1 ]]
grep -Fq 'FIXTURE_CONF_OPTS=--no-optional-feature' "$output/.tdvp-make.log"
grep -Fq 'FIXTURE_DEPENDENCIES=' "$output/.tdvp-make.log"
for directory in bin etc sbin usr/bin usr/lib usr/sbin usr/share; do
  test -d "$install_root/$directory"
done

rm -f -- "$output/.config.old" "$output/.tdvp-make.log"
printf 'ORIGINAL_WITHOUT_OLD=y\n' >"$output/.config"
config_hash=$(sha256sum "$output/.config" | awk '{print $1}')
run_fixture
[[ "$(sha256sum "$output/.config" | awk '{print $1}')" == "$config_hash" ]]
[[ ! -e "$output/.config.old" && ! -L "$output/.config.old" ]]
[[ "$(grep -Fc 'olddefconfig' "$output/.tdvp-make.log")" -eq 1 ]]

if tdvp_buildroot_install "$output" "$install_root" \
  --make-variable 'FIXTURE_BAD=$(touch)' --target fixture \
  >"$work/invalid-make-variable.log" 2>&1; then
  echo 'Buildroot session accepted an unsafe make-variable value' >&2
  exit 1
fi
grep -Fq 'invalid Buildroot make variable: FIXTURE_BAD=$(touch)' \
  "$work/invalid-make-variable.log"

fixture_repo="$work/source-lock-fixture"
fixture_package="$fixture_repo/packages/example"
fixture_cache="$work/source-cache"
mkdir -p "$fixture_package" "$fixture_repo/scripts" "$fixture_cache"
cp -- "$repo_root/scripts/verify-source-lock.sh" "$fixture_repo/scripts/verify-source-lock.sh"
printf 'fixture Buildroot archive\n' >"$work/example.tar.xz"
archive_hash=$(sha256sum "$work/example.tar.xz" | awk '{print $1}')
printf 'fixture Buildroot host-helper archive\n' >"$work/host-helper.tar.gz"
helper_hash=$(sha256sum "$work/host-helper.tar.gz" | awk '{print $1}')
mkdir -p "$fixture_cache/sha256/$archive_hash"
cp -- "$work/example.tar.xz" "$fixture_cache/sha256/$archive_hash/example.tar.xz"
mkdir -p "$fixture_cache/sha256/$helper_hash"
cp -- "$work/host-helper.tar.gz" "$fixture_cache/sha256/$helper_hash/host-helper.tar.gz"
cat >"$fixture_package/source.lock" <<EOF
FORMAT_VERSION='1'
SOURCE_TYPE='buildroot-derived'
UPSTREAM_NAME='fixture'
UPSTREAM_LICENSE='MIT'
UPSTREAM_VERSION='1.0'
UPSTREAM_REVISION='1111111111111111111111111111111111111111'
SOURCE_SNAPSHOT='https://example.invalid/buildroot/fixture'
SOURCE_SELECTION_REASON='Hermetic policy-test fixture.'
SECURITY_STATUS='Not published; test fixture only.'
VERIFIED_BY='test'
VERIFIED_AT='2026-09-02'
VERIFICATION_REFERENCE='https://example.invalid/buildroot/fixture.hash'
SOURCE_ARTIFACT_1_URL='https://example.invalid/example.tar.xz'
SOURCE_ARTIFACT_1_FILE='example.tar.xz'
SOURCE_ARTIFACT_1_SHA256='$archive_hash'
SOURCE_ARTIFACT_2_URL='https://example.invalid/host-helper.tar.gz'
SOURCE_ARTIFACT_2_FILE='host-helper.tar.gz'
SOURCE_ARTIFACT_2_SHA256='$helper_hash'
EOF
TDVP_SOURCE_CACHE_ROOT="$fixture_cache" \
  private_download=$(tdvp_prepare_locked_buildroot_download "$fixture_package")
test -d "$private_download"
test -f "$private_download/example.tar.xz"
test ! -L "$private_download/example.tar.xz"
cmp -s "$work/example.tar.xz" "$private_download/example.tar.xz"
test "$(stat -c '%a' "$private_download/example.tar.xz")" = 444
test -f "$private_download/host-helper.tar.gz"
test ! -L "$private_download/host-helper.tar.gz"
cmp -s "$work/host-helper.tar.gz" "$private_download/host-helper.tar.gz"
test "$(stat -c '%a' "$private_download/host-helper.tar.gz")" = 444
rm -rf -- "$private_download"

echo 'Buildroot feed session policy test passed'
