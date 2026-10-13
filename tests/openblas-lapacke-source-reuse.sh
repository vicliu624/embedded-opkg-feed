#!/usr/bin/env bash
# Validate source headers against installed runtime without rebuilding OpenBLAS.
set -Eeuo pipefail
[[ $# -eq 3 ]] || { echo 'usage: test SDK_ROOT INSTALLED_ROOT SOURCE_ARCHIVE' >&2; exit 64; }
sdk=$(realpath -e -- "$1")
root=$(realpath -e -- "$2")
archive=$(realpath -e -- "$3")
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
expected=38240eee1b29e2bde47ebb5d61160207dc68668a54cac62c076bb5032013b1eb
printf '%s  %s\n' "$expected" "$archive" | sha256sum -c -
[[ -f "$sdk/tdvp-sdk-manifest.json" && -f "$root/usr/lib/libopenblas.so.0" ]] || exit 65
work=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-openblas-header-check.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
# These public headers are unmodified source files, not generated ABI config.
tar -xf "$archive" -C "$work" \
 OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include/lapack.h \
 OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include/lapacke.h \
 OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include/lapacke_config.h \
 OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include/lapacke_mangling.h
"$sdk/bin/riscv64-unknown-linux-gnu-gcc" -march=rv64imafdc -mabi=lp64d \
 -I"$work/OpenBLAS-0.3.29/lapack-netlib/LAPACKE/include" \
 "$repo/tests/openblas-lapacke-smoke.c" -L"$root/usr/lib" \
 -Wl,-rpath-link,"$root/usr/lib" -l:libopenblas.so.0 -lm -o "$work/consumer"
qemu-riscv64 -cpu rv64,v=false -L "$root" -E "LD_LIBRARY_PATH=$root/usr/lib" "$work/consumer"
echo 'OpenBLAS source-header reuse: PASS; no runtime build or development receipt produced'
