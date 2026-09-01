#!/usr/bin/env bash
# GitHub CLI has no Buildroot 2025.02.1 target recipe.  Build it from the
# reviewed upstream source with Go for linux/riscv64; never fetch an upstream
# prebuilt binary (which would be for another ABI or opaque build pipeline).
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64;
}
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
go version | grep -Eq '^go version go1\.26\.7 ' || {
  echo 'gh r9 requires the reviewed Go 1.26.7 build host' >&2; exit 65;
}
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo 'matching K230 RISC-V readelf is missing' >&2; exit 66; }

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT
archive="$work_root/$SOURCE_ARCHIVE"
curl --fail --location --proto '=https' --tlsv1.2 --retry 3 \
  "https://github.com/cli/cli/archive/$SOURCE_REVISION.tar.gz" -o "$archive"
printf '%s  %s\n' "$SOURCE_ARCHIVE_SHA256" "$archive" | sha256sum -c -
tar -xzf "$archive" -C "$work_root"
source_root=$(find "$work_root" -mindepth 1 -maxdepth 1 -type d -name 'cli-*' -print -quit)
[[ -n "$source_root" && -f "$source_root/go.mod" ]] || { echo 'verified gh source archive did not unpack as expected' >&2; exit 67; }
grep -Fqx 'go 1.26.0' "$source_root/go.mod" || { echo 'gh source Go language version changed from reviewed r9 input' >&2; exit 68; }

export GOMODCACHE="$work_root/go-mod-cache"
export GOCACHE="$work_root/go-cache"
export GOTOOLCHAIN=local
mkdir -p "$GOMODCACHE" "$GOCACHE"
(
  cd -- "$source_root"
  GOOS=linux GOARCH=riscv64 CGO_ENABLED=0 \
    go build -trimpath -buildvcs=false -o "$work_root/gh" ./cmd/gh
)
[[ -x "$work_root/gh" ]] || { echo 'Go did not produce gh' >&2; exit 69; }
"$readelf_tool" -h "$work_root/gh" | grep -Fq 'Machine:                           RISC-V' || {
  echo 'gh is not a RISC-V binary' >&2; exit 70;
}
if "$readelf_tool" -d "$work_root/gh" 2>/dev/null | grep -F 'Shared library:'; then
  echo 'gh must remain a self-contained Go executable; unexpected dynamic dependency' >&2
  exit 71
fi
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
install -Dm 0755 "$work_root/gh" "$payload_dir/usr/bin/gh"
echo "gh payload ready: $payload_dir"
