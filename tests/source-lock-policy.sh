#!/usr/bin/env bash
# Exercise the non-executable parser and the offline content-addressed cache
# without downloading from a network service.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
verifier="$repo_root/scripts/verify-source-lock.sh"
fetcher="$repo_root/scripts/fetch-source-cache.sh"
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

package_dir="$work_root/packages/example"
mkdir -p -- "$package_dir/patches"
printf 'example source artifact\n' >"$work_root/example-1.0.tar.gz"
printf 'TDVP patch\n' >"$package_dir/patches/0001-example.patch"
printf 'locked non-executable build input\n' >"$package_dir/build-input.lock"
artifact_hash=$(sha256sum "$work_root/example-1.0.tar.gz" | awk '{print $1}')
patch_hash=$(sha256sum "$package_dir/patches/0001-example.patch" | awk '{print $1}')
build_input_hash=$(sha256sum "$package_dir/build-input.lock" | awk '{print $1}')

printf '%s\n' \
  "FORMAT_VERSION='1'" \
  "SOURCE_TYPE='release-tarball'" \
  "UPSTREAM_NAME='Example'" \
  "UPSTREAM_LICENSE='MIT'" \
  "UPSTREAM_VERSION='1.0'" \
  "UPSTREAM_REVISION='v1.0'" \
  "SOURCE_SNAPSHOT='https://example.invalid/releases/v1.0'" \
  "SOURCE_SELECTION_REASON='Parser fixture'" \
  "SOURCE_ARTIFACT_1_URL='https://example.invalid/example-1.0.tar.gz'" \
  "SOURCE_ARTIFACT_1_FILE='example-1.0.tar.gz'" \
  "SOURCE_ARTIFACT_1_SHA256='$artifact_hash'" \
  "SOURCE_PATCH_1_FILE='patches/0001-example.patch'" \
  "SOURCE_PATCH_1_SHA256='$patch_hash'" \
  "SOURCE_PATCH_1_REASON='Fixture patch'" \
  "SOURCE_BUILD_INPUT_1_FILE='build-input.lock'" \
  "SOURCE_BUILD_INPUT_1_SHA256='$build_input_hash'" \
  "SOURCE_BUILD_INPUT_1_REASON='Fixture non-executable build input'" \
  "NON_PLATFORM_BUILD_INPUTS=''" \
  "SECURITY_STATUS='No known unresolved advisories.'" \
  "VERIFIED_BY='TDVP test'" \
  "VERIFIED_AT='2026-09-02'" \
  "VERIFICATION_REFERENCE='tests/source-lock-policy.sh'" \
  >"$package_dir/source.lock"

bash "$verifier" --package-dir "$package_dir"
artifacts=$(bash "$verifier" --package-dir "$package_dir" --emit-artifacts)
expected_artifact=$'https://example.invalid/example-1.0.tar.gz\texample-1.0.tar.gz\t'
[[ "$artifacts" == "$expected_artifact$artifact_hash" ]] || {
  echo 'source-lock artifact output is not deterministic' >&2
  exit 1
}

# A local build input is not executable recipe code. It must be a direct,
# regular package file and its exact digest is part of the provenance record.
printf 'tampered build input\n' >"$package_dir/build-input.lock"
if bash "$verifier" --package-dir "$package_dir"; then
  echo 'source-lock parser accepted a changed local build input' >&2
  exit 1
fi
printf 'locked non-executable build input\n' >"$package_dir/build-input.lock"
bash "$verifier" --package-dir "$package_dir"

cache_root="$work_root/cache"
cache_file="$cache_root/sha256/$artifact_hash/example-1.0.tar.gz"
mkdir -p -- "$(dirname -- "$cache_file")"
cp -- "$work_root/example-1.0.tar.gz" "$cache_file"
bash "$fetcher" --offline --cache "$cache_root" --package-dir "$package_dir"
[[ "$(sha256sum "$cache_file" | awk '{print $1}')" == "$artifact_hash" ]]

# An old host may need an explicitly supplied, locally managed CA bundle to
# reach a legitimate HTTPS source. The option must keep its narrow boundary:
# a regular PEM file is accepted, while symlinks and non-PEM input are rejected
# before any cache operation can use them. The artifact digest remains checked
# as above even when a CA bundle is involved.
ca_bundle="$work_root/extra-trust.pem"
printf '%s\n' '-----BEGIN CERTIFICATE-----' 'fixture' '-----END CERTIFICATE-----' >"$ca_bundle"
bash "$fetcher" --offline --ca-bundle "$ca_bundle" --cache "$cache_root" --package-dir "$package_dir"
printf '%s\n' 'not a certificate' >"$work_root/not-a-bundle"
if bash "$fetcher" --offline --ca-bundle "$work_root/not-a-bundle" --cache "$cache_root" --package-dir "$package_dir"; then
  echo 'source cache accepted a non-PEM CA bundle' >&2
  exit 1
fi
ln -s -- "$ca_bundle" "$work_root/ca-bundle-link"
if bash "$fetcher" --offline --ca-bundle "$work_root/ca-bundle-link" --cache "$cache_root" --package-dir "$package_dir"; then
  echo 'source cache accepted a symlinked CA bundle' >&2
  exit 1
fi

# A Buildroot-derived recipe is anchored to the exact Buildroot commit, not a
# release name/tag that could be moved later.
buildroot_dir="$work_root/packages/buildroot-example"
mkdir -p -- "$buildroot_dir/patches"
cp -- "$package_dir/source.lock" "$buildroot_dir/source.lock"
cp -- "$package_dir/patches/0001-example.patch" "$buildroot_dir/patches/0001-example.patch"
cp -- "$package_dir/build-input.lock" "$buildroot_dir/build-input.lock"
sed -i \
  -e "s/SOURCE_TYPE='release-tarball'/SOURCE_TYPE='buildroot-derived'/" \
  -e "s/UPSTREAM_REVISION='v1.0'/UPSTREAM_REVISION='2025.02.1'/" \
  "$buildroot_dir/source.lock"
if bash "$verifier" --package-dir "$buildroot_dir"; then
  echo 'buildroot-derived lock accepted a non-commit revision' >&2
  exit 1
fi
sed -i "s/UPSTREAM_REVISION='2025.02.1'/UPSTREAM_REVISION='1111111111111111111111111111111111111111'/" \
  "$buildroot_dir/source.lock"
bash "$verifier" --package-dir "$buildroot_dir"

# Debian source packages are admitted as source input only. The parser requires
# a .dsc plus its separately locked source tarballs; it never accepts a .deb.
debian_dir="$work_root/packages/debian-example"
mkdir -p -- "$debian_dir"
debian_hash_1=$(printf '1%.0s' {1..64})
debian_hash_2=$(printf '2%.0s' {1..64})
debian_hash_3=$(printf '3%.0s' {1..64})
printf '%s\n' \
  "FORMAT_VERSION='1'" \
  "SOURCE_TYPE='debian-source'" \
  "UPSTREAM_NAME='example-debian-source'" \
  "UPSTREAM_LICENSE='MIT'" \
  "UPSTREAM_VERSION='1.0-1'" \
  "UPSTREAM_REVISION='1.0-1'" \
  "SOURCE_SNAPSHOT='https://snapshot.debian.org/archive/debian/20260101T000000Z/'" \
  "SOURCE_SELECTION_REASON='Debian source parser fixture'" \
  "SOURCE_ARTIFACT_1_URL='https://snapshot.debian.org/archive/debian/example_1.0-1.dsc'" \
  "SOURCE_ARTIFACT_1_FILE='example_1.0-1.dsc'" \
  "SOURCE_ARTIFACT_1_SHA256='$debian_hash_1'" \
  "SOURCE_ARTIFACT_2_URL='https://snapshot.debian.org/archive/debian/example_1.0.orig.tar.xz'" \
  "SOURCE_ARTIFACT_2_FILE='example_1.0.orig.tar.xz'" \
  "SOURCE_ARTIFACT_2_SHA256='$debian_hash_2'" \
  "SOURCE_ARTIFACT_3_URL='https://snapshot.debian.org/archive/debian/example_1.0-1.debian.tar.xz'" \
  "SOURCE_ARTIFACT_3_FILE='example_1.0-1.debian.tar.xz'" \
  "SOURCE_ARTIFACT_3_SHA256='$debian_hash_3'" \
  "NON_PLATFORM_BUILD_INPUTS=''" \
  "SECURITY_STATUS='Fixture only.'" \
  "VERIFIED_BY='TDVP test'" \
  "VERIFIED_AT='2026-09-02'" \
  "VERIFICATION_REFERENCE='tests/source-lock-policy.sh'" \
  >"$debian_dir/source.lock"
bash "$verifier" --package-dir "$debian_dir"

# The CI path validates package recipes changed since a Git base commit. It
# accepts a valid lock, rejects its removal, and allows an explicit exemption
# for a package with no third-party source.
git_root="$work_root/git-repo"
mkdir -p -- "$git_root/packages/example/patches"
cp -- "$package_dir/source.lock" "$git_root/packages/example/source.lock"
cp -- "$package_dir/patches/0001-example.patch" "$git_root/packages/example/patches/0001-example.patch"
cp -- "$package_dir/build-input.lock" "$git_root/packages/example/build-input.lock"
printf "%s\n" "PACKAGE='example'" >"$git_root/packages/example/package.env"
git -C "$git_root" init -q
git -C "$git_root" add packages
git -C "$git_root" -c user.name='TDVP test' -c user.email='tests@example.invalid' commit -qm baseline
base_revision=$(git -C "$git_root" rev-parse HEAD)
printf '%s\n' '# changed package hook' >"$git_root/packages/example/build.sh"
git -C "$git_root" add packages/example/build.sh
git -C "$git_root" -c user.name='TDVP test' -c user.email='tests@example.invalid' commit -qm changed-recipe
bash "$verifier" --repo-root "$git_root" --changed-since "$base_revision"
rm -f -- "$git_root/packages/example/source.lock"
git -C "$git_root" add -u packages/example/source.lock
git -C "$git_root" -c user.name='TDVP test' -c user.email='tests@example.invalid' commit -qm removed-lock
if bash "$verifier" --repo-root "$git_root" --changed-since "$base_revision"; then
  echo 'changed recipe passed without a source lock or an exemption' >&2
  exit 1
fi
printf "%s\n" "SOURCE_LOCK_EXEMPT_REASON='Pure TDVP-owned fixture with no imported source.'" >>"$git_root/packages/example/package.env"
git -C "$git_root" add packages/example/package.env
git -C "$git_root" -c user.name='TDVP test' -c user.email='tests@example.invalid' commit -qm source-exemption
bash "$verifier" --repo-root "$git_root" --changed-since "$base_revision"
# A strict whole-repository audit has the same narrow exception: an explicit,
# literal exemption is valid only for a recipe that imports no third-party
# source. This lets installation profiles participate in --require-source-locks
# without inventing a meaningless self-source lock.
bash "$verifier" --repo-root "$git_root" --all --require-source-locks

# An apparent shell assignment must fail the literal parser and must never be
# evaluated by it. No newline is needed: the parser accepts a final line at EOF.
printf '%s' "UPSTREAM_NAME='Example'; false" >"$package_dir/source.lock"
if bash "$verifier" --package-dir "$package_dir"; then
  echo 'source-lock parser accepted executable input' >&2
  exit 1
fi

echo 'source-lock parser and offline cache policy: PASS'
