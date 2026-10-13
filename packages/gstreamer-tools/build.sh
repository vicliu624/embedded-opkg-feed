#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/elf-runtime-policy.sh"
stage=${TDVP_FEED_STAGING_ROOT:?}
feed=${TDVP_FEED_OUTPUT_DIR:?}
proof=$(mktemp -d /tmp/tdvp-gstreamer-tools-proof.XXXXXX)
trap 'rm -rf -- "$proof"' EXIT
mkdir "$proof/reference"
python3 "$repo_root/scripts/extract-split-provider.py" \
 "$feed/libgstreamer_1.28.7-1_riscv64.ipk" "$proof/reference" \
 --package libgstreamer --version 1.28.7-1 --library usr/lib/libgstreamer-1.0.so.0.2807.0
cmp "$stage/usr/lib/libgstreamer-1.0.so.0.2807.0" "$proof/reference/usr/lib/libgstreamer-1.0.so.0.2807.0"
notices="$proof/reference/usr/share/licenses/libgstreamer"
python3 - "$notices" "$package_dir/source.lock" <<'PY'
from pathlib import Path
import hashlib, json, re, sys
notices, lock = map(Path, sys.argv[1:])
origin = json.loads((notices / 'SOURCE.json').read_text())
assert origin['package'] == 'libgstreamer' and origin['notice_sha256']
expected = re.search(r"^SOURCE_ARTIFACT_1_SHA256='([0-9a-f]{64})'", lock.read_text(), re.M)
assert expected and origin['source']['SOURCE_ARTIFACT_1_SHA256'] == expected[1]
for name, digest in origin['notice_sha256'].items():
    path = notices / name
    assert not path.is_symlink() and path.resolve().is_relative_to(notices.resolve())
    assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
PY
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/bin"
for tool in gst-inspect-1.0 gst-launch-1.0 gst-typefind-1.0; do
 cp "$stage/usr/bin/$tool" "$payload/usr/bin/"
done
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$notices" "$package_dir" "$payload" --license-file COPYING
echo "GStreamer command tools split payload ready: $payload"
