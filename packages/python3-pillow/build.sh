#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
source "$package_dir/../../support/elf-runtime-policy.sh"
stage=${TDVP_FEED_STAGING_ROOT:?}
[[ -f "$stage/usr/include/python3.13/Python.h" ]] || exit 65
work=$(mktemp -d /tmp/tdvp-pillow-source.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/source" "$work/sysroot" "$work/python-config"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
cp -a "$stage/usr/." "$work/sysroot/usr/"
sysroot="$work/sysroot"
mapfile -t configs < <(find "$stage/usr/lib/python3.13" -maxdepth 1 -name '_sysconfigdata*.py')
[[ ${#configs[@]} == 1 ]] || exit 66
config=${configs[0]}
python3 - "$config" "$work/python-config/${config##*/}" "$sysroot" <<'PY'
import ast, pathlib, sys
source, destination, root = sys.argv[1:]
tree = ast.parse(pathlib.Path(source).read_text())
values = next(ast.literal_eval(node.value) for node in tree.body if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'build_time_vars' for t in node.targets))
for key in ['LIBPC', 'INCLUDEPY', 'CONFINCLUDEPY', 'LIBDIR', 'LIBPL']:
    value = values.get(key)
    if isinstance(value, str) and value.startswith('/usr/'): values[key] = root + value
for key in ['installed_base', 'installed_platbase', 'base', 'platbase', 'prefix', 'exec_prefix']: values[key] = root + '/usr'
pathlib.Path(destination).write_text('build_time_vars = ' + repr(values) + '\n')
PY
export _PYTHON_SYSCONFIGDATA_NAME=$(basename "$config" .py)
export _PYTHON_HOST_PLATFORM=linux-riscv64 PYTHONPATH="$work/python-config"
export CC="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc --sysroot=$sysroot"
export CXX="$sdk_root/bin/riscv64-unknown-linux-gnu-g++ --sysroot=$sysroot"
export LDSHARED="$CC -shared"
export CFLAGS="-O1 -fPIC -I$sysroot/usr/include"
export CPPFLAGS="-I$sysroot/usr/include" LDFLAGS="-L$sysroot/usr/lib -Wl,-rpath-link,$sysroot/usr/lib"
export PKG_CONFIG=/usr/bin/pkg-config PKG_CONFIG_SYSROOT_DIR="$sysroot"
export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig" PKG_CONFIG_PATH=''
cd "$source_root"
python3 setup.py build_ext --disable-platform-guessing \
  --enable-jpeg --enable-zlib --enable-tiff --enable-webp \
  --disable-raqm --disable-imagequant --disable-jpeg2000
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
python3 setup.py install --root="$payload" --prefix=/usr \
  --single-version-externally-managed --record="$work/install-record"
[[ -d "$payload/usr/lib/python3.13/site-packages/PIL" ]] || exit 67
while IFS= read -r -d '' elf; do
  "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" -h "$elf" | grep -Fq 'Machine:                           RISC-V' || exit 68
  tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$elf"
done < <(find "$payload" -type f -name '*.so' -print0)
mkdir -p "$stage/usr"
python3 "$package_dir/../../support/install-source-licenses.py" \
  "$source_root" "$package_dir" "$payload" \
  --license-file LICENSE --license-file src/thirdparty/raqm/COPYING
cp -a "$payload/usr/." "$stage/usr/"
printf '%s\n' "Pillow Python extension ready: $payload"
