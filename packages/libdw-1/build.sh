#!/usr/bin/env bash
# Split the validated libelf build; do not compile elfutils again.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
source "$package_dir/../../scripts/tdvp-k230-sdk.sh"
tdvp_require_k230_sdk "$4"
stage=${TDVP_FEED_STAGING_ROOT:?}
[[ -d "$stage" && ! -L "$stage" ]] || exit 65
grep -Fxq 'package=libelf-1' "$stage/.tdvp-direct-source-libelf-1"
grep -Fxq 'version=0.196-1' "$stage/.tdvp-direct-source-libelf-1"
grep -Fxq 'source-archive=elfutils-0.196.tar.bz2' "$stage/.tdvp-direct-source-libelf-1"
proof=$(mktemp -d /tmp/tdvp-elfutils-split-proof.XXXXXX)
trap 'rm -rf -- "$proof"' EXIT
mkdir -p "$proof/usr/lib"
cp "$stage/usr/lib/libelf-0.196.so" "$proof/usr/lib/"
tdvp_assert_direct_archive_elfs "$TDVP_K230_READELF" "$TDVP_K230_STRIP" "$proof"
feed=${TDVP_FEED_OUTPUT_DIR:?libdw split requires the verified libelf output feed}
provider="$feed/libelf-1_0.196-1_riscv64.ipk"
[[ -f "$provider" ]] || { echo 'libelf provider IPK is missing' >&2; exit 66; }
mkdir "$proof/reference"
python3 "$package_dir/../../scripts/extract-split-provider.py" "$provider" "$proof/reference" \
  --package libelf-1 --version 0.196-1 --library usr/lib/libelf-0.196.so
cmp "$proof/usr/lib/libelf-0.196.so" "$proof/reference/usr/lib/libelf-0.196.so"
[[ -f "$stage/usr/lib/libdw-0.196.so" && -L "$stage/usr/lib/libdw.so.1" ]] || exit 66
notices="$proof/reference/usr/share/licenses/libelf-1"
python3 - "$notices" "$package_dir/source.lock" <<'PY'
from pathlib import Path
import hashlib, json, re, sys
notices, lock = map(Path, sys.argv[1:])
origin = json.loads((notices / 'SOURCE.json').read_text())
assert origin['package'] == 'libelf-1' and origin['notice_sha256'], 'missing libelf notice identity'
expected = re.search(r"^SOURCE_ARTIFACT_1_SHA256='([0-9a-f]{64})'", lock.read_text(), re.M)
assert expected and origin['source']['SOURCE_ARTIFACT_1_SHA256'] == expected[1], 'split notices have a different source'
for name, digest in origin['notice_sha256'].items():
    path = notices / name
    assert not path.is_symlink() and path.resolve().is_relative_to(notices.resolve())
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest, 'modified dependency notice'
PY
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/lib"
cp -a "$stage/usr/lib/"libdw*.so* "$payload/usr/lib/"
tdvp_assert_direct_archive_elfs "$TDVP_K230_READELF" "$TDVP_K230_STRIP" "$payload"
python3 "$package_dir/../../support/install-source-licenses.py" "$notices" "$package_dir" "$payload"
echo "libdw split-source payload ready: $payload"
