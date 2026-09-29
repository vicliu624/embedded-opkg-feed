#!/usr/bin/env bash
# Finalize verified raw build artifacts without compiling or signing packages.
set -Eeuo pipefail
IFS=$'\n\t'
if [[ $# -ne 8 || "$1" != --platform || "$3" != --base-root || "$5" != --source || "$7" != --output ]]; then
  echo "usage: $0 --platform <slug> --base-root <root> --source <raw-feed> --output <new-directory>" >&2
  exit 64
fi
platform=$2
base_root=$(realpath -e -- "$4")
source_dir=$(realpath -e -- "$6")
output=$(realpath -m -- "$8")
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(dirname -- "$script_dir")
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform"
[[ ! -e "$output" && ! -L "$output" ]] || { echo "output already exists: $output" >&2; exit 65; }
[[ -n "${TDVP_SDK_ROOT:-}" && -f "$TDVP_SDK_ROOT/verify-sdk.py" ]] || {
  echo 'a verified matching TDVP_SDK_ROOT is required' >&2; exit 66;
}
[[ "${IMAGE_OWNERSHIP_MANIFEST_SHA256:-}" =~ ^[0-9a-f]{64}$ ]] || {
  echo 'platform image ownership digest is missing' >&2; exit 67;
}
bash "$script_dir/verify-feed.sh" --platform "$platform" "$source_dir"
# Allocate beside the destination so the final rename stays on one filesystem.
mkdir -p -- "$(dirname -- "$output")"
work_root=$(mktemp -d "$(dirname -- "$output")/.tdvp-finalize.XXXXXXXX")
trap 'rm -rf -- "$work_root"' EXIT
candidate="$work_root/candidate"
python3 "$script_dir/compose_image_backed_feed.py" \
  --source "$source_dir" --image-root "$base_root" \
  --image-manifest-sha256 "$IMAGE_OWNERSHIP_MANIFEST_SHA256" --output "$candidate"
bash "$script_dir/verify-feed.sh" --platform "$platform" "$candidate"
bash "$script_dir/verify-runtime-closure.sh" --platform "$platform" --base-root "$base_root" "$candidate"
bash "$script_dir/verify-target-runtime-coverage.sh" --platform "$platform" --base-root "$base_root" "$candidate"
# Audit only the delivered payload. Image references have already been checked
# against locked image bytes by the two reference-aware gates above.
python3 - "$candidate" "$TDVP_SDK_ROOT" "$script_dir" <<'PY'
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

candidate, sdk, scripts = map(Path, sys.argv[1:])
for package in sorted(candidate.glob('*.ipk')):
    with tempfile.TemporaryDirectory(prefix='tdvp-payload-policy-') as directory:
        data = subprocess.check_output(['ar', 'p', str(package), 'data.tar.gz'])
        with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
            archive.extractall(directory, filter='data')
        subprocess.run([sys.executable, str(scripts / 'verify-published-sdk-payload.py'),
                        str(sdk), directory], check=True)
PY
# Never merge into or overwrite an existing candidate.
python3 - "$candidate" "$output" <<'PY'
from pathlib import Path
import sys

source, output = map(Path, sys.argv[1:])
if output.exists() or output.is_symlink():
    raise SystemExit('output appeared during validation; refusing replacement')
source.rename(output)
PY
echo "unsigned image-backed candidate validated: $output"
echo 'Signing, paired maintenance-image validation and device acceptance remain required.'
