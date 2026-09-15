#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
install -Dm 0644 "$package_dir/README" "$payload_dir/usr/share/doc/tdvp-diagnostics/README"
echo "tdvp-diagnostics profile payload ready: $payload_dir"
