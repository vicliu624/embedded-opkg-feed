#!/usr/bin/env bash
# Build the reviewed Debian CA source through Buildroot, then explicitly
# materialise the target bundle and hash links that Buildroot normally adds
# during final image finalisation. The payload owns both link targets and links.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "ca-certificates does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_CA_CERTIFICATES_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"

[[ -d "$sdk_root" ]] || {
  echo 'ca-certificates needs a matching Buildroot SDK host directory' >&2
  exit 66
}
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'CA_CERTIFICATES_VERSION = 20230311' \
  "$tree/package/ca-certificates/ca-certificates.mk" || {
  echo 'locked Buildroot CA source version differs from the reviewed feed recipe' >&2
  exit 67
}
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" \
  "$tree/package/ca-certificates/ca-certificates.hash" || {
  echo 'locked Buildroot CA archive hash differs from the reviewed feed recipe' >&2
  exit 68
}
host_rehash="$output/host/bin/c_rehash"
[[ -x "$host_rehash" ]] || {
  echo "matching SDK has no OpenSSL certificate-hash helper: $host_rehash" >&2
  exit 69
}

download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
install_root=$(mktemp -d)
payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix=/tmp/tdvp-command-payload.
cleanup() {
  local rc=$?
  rm -rf -- "$install_root"
  rm -rf -- "$download_dir"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tdvp_buildroot_install "$output" "$install_root" \
  --offline-download-dir "$download_dir" \
  --enable BR2_PACKAGE_CA_CERTIFICATES \
  --target ca-certificates

certificate_source="$install_root/usr/share/ca-certificates"
[[ -d "$certificate_source" ]] || {
  echo 'Buildroot CA target install omitted certificate data' >&2
  exit 70
}
mapfile -d '' certificate_files < <(
  find "$certificate_source" -type f -name '*.crt' -print0 | LC_ALL=C sort -z
)
[[ ${#certificate_files[@]} -gt 0 ]] || {
  echo 'Buildroot CA target install produced no certificate files' >&2
  exit 71
}
certificate_dir="$install_root/etc/ssl/certs"
mkdir -p -- "$certificate_dir"
for certificate_file in "${certificate_files[@]}"; do
  certificate_relative=${certificate_file#"$install_root"/}
  ln -s -- "../../../$certificate_relative" \
    "$certificate_dir/$(basename "${certificate_file%.crt}").pem"
done
for certificate_file in "${certificate_files[@]}"; do
  cat -- "$certificate_file"
done >"$certificate_dir/ca-certificates.crt"
"$host_rehash" "$certificate_dir"
[[ -s "$certificate_dir/ca-certificates.crt" ]] || {
  echo 'generated CA bundle is empty' >&2
  exit 72
}
find "$certificate_dir" -maxdepth 1 -type l -name '*.0' -print -quit | grep -q . || {
  echo 'generated CA certificate hashes are missing' >&2
  exit 73
}

if [[ -e "$payload_link" || -L "$payload_link" ]]; then
  [[ -L "$payload_link" ]] || {
    echo "refusing to replace non-generated payload path: $payload_link" >&2
    exit 74
  }
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]] || {
    echo "refusing to replace unexpected payload target: $previous_payload" >&2
    exit 75
  }
  rm -f -- "$payload_link"
  rm -rf -- "$previous_payload"
fi
payload_dir=$(mktemp -d "$temporary_prefix"XXXXXX)
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
mkdir -p -- "$payload_dir/etc" "$payload_dir/usr/share"
cp -a -- "$install_root/etc/ssl" "$payload_dir/etc/ssl"
cp -a -- "$certificate_source" "$payload_dir/usr/share/ca-certificates"
install -Dm 0644 "$output/build/ca-certificates-20230311/debian/copyright" \
  "$payload_dir/usr/share/licenses/ca-certificates/copyright"
payload_ready=1
echo "ca-certificates payload ready: $payload_dir"
