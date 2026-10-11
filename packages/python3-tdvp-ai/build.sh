#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/source-archive-library.sh"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/share/licenses/python3-tdvp-ai"
install -m 0644 "$package_dir/LICENSE" "$payload/usr/share/licenses/python3-tdvp-ai/LICENSE"
mkdir -p "$payload/usr/lib/python3.13/site-packages"
cp -a "$package_dir/src/tdvp_ai" "$payload/usr/lib/python3.13/site-packages/"
