#!/usr/bin/env bash
set -Eeuo pipefail
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$package_dir/../../support/vim-plugin-build.sh" "$package_dir"
