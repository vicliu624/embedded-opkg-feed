#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/source-archive-library.sh"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload/usr/share/licenses/tdvp-ai-tools"
install -m 0644 "$package_dir/LICENSE" "$payload/usr/share/licenses/tdvp-ai-tools/LICENSE"
mkdir -p "$payload/usr/bin"
install -m 0755 "$package_dir/../python3-tdvp-ai/src/tdvp-ai-info" "$payload/usr/bin/tdvp-ai-info"
