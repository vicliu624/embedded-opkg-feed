#!/usr/bin/env bash
# Source-locked PEP 517 builds; target dependencies never come from pip.
tdvp_build_python_wheel_source() (
  set -Eeuo pipefail
  local package_dir=$1 sdk_root=$2 work source_root payload wheel stage config sysroot
  source "$package_dir/package.env"
  source "$package_dir/../../scripts/feed-platform.sh"
  tdvp_assert_package_host_dependencies "$package_dir"
  source "$package_dir/../../support/source-archive-library.sh"
  source "$package_dir/../../support/elf-runtime-policy.sh"
  stage=${TDVP_FEED_STAGING_ROOT:?}
  python3 - "$package_dir/../../support/python-wheel-host-requirements.txt" <<'PY' || {
import importlib.metadata, pathlib, sys
for line in pathlib.Path(sys.argv[1]).read_text().splitlines():
    if not line.strip() or line.startswith('#'):
        continue
    name, expected = line.split()[0].split('==')
    actual = importlib.metadata.version(name)
    if actual != expected:
        raise SystemExit(f'host tool version mismatch: {name}: {actual}, required {expected}')
PY
    echo 'Python package builder requires its pinned PEP 517 host environment' >&2; exit 65;
  }
  work=$(mktemp -d /tmp/tdvp-python-wheel.XXXXXX)
  trap 'rm -rf -- "$work"' EXIT
  mkdir -p "$work/source" "$work/wheels"
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  if [[ -d "$package_dir/patches" ]]; then
    local source_patch
    for source_patch in "$package_dir/patches/"*.patch; do
      [[ -f "$source_patch" ]] || continue
      patch --directory="$source_root" -p1 --fuzz=0 --forward --dry-run < "$source_patch"
      patch --directory="$source_root" -p1 --fuzz=0 --forward < "$source_patch"
    done
  fi
  if [[ ${PACKAGE_PYTHON_NATIVE:-0} == 1 ]]; then
    [[ -f "$stage/usr/include/python3.13/Python.h" ]] || exit 66
    mkdir -p "$work/sysroot" "$work/python-config"
    cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
    cp -a --reflink=auto "$stage/usr/." "$work/sysroot/usr/"
    sysroot="$work/sysroot"
    local -a configs=()
    mapfile -t configs < <(find "$stage/usr/lib/python3.13" -maxdepth 1 -name '_sysconfigdata*.py')
    [[ ${#configs[@]} == 1 ]] || exit 67
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
  fi
  # Disable isolated dependency installation: missing host tools fail here.
  PIP_NO_INDEX=1 python3 -m build --wheel --no-isolation --outdir "$work/wheels" "$source_root"
  local -a wheels=("$work/wheels/"*.whl)
  [[ ${#wheels[@]} == 1 && -f ${wheels[0]} ]] || exit 68
  wheel=${wheels[0]}
  payload=$(tdvp_prepare_generated_payload_root "$package_dir")
  python3 "$package_dir/../../scripts/install-python-wheel.py" "$wheel" "$payload"
  local elf count=0
  while IFS= read -r -d '' elf; do
    [[ ${PACKAGE_PYTHON_NATIVE:-0} == 1 ]] || { echo 'pure Python wheel contains native code' >&2; exit 69; }
    tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$elf"
    count=$((count + 1))
  done < <(find "$payload" -type f -name '*.so' -print0)
  [[ ${PACKAGE_PYTHON_NATIVE:-0} != 1 || $count -gt 0 ]] || exit 70
  python3 "$package_dir/../../scripts/verify-published-sdk-payload.py" "$sdk_root" "$payload"
  mkdir -p "$stage/usr"
  cp -a "$payload/usr/." "$stage/usr/"
  printf '%s\n' "$PACKAGE source-built Python wheel payload ready: $payload"
)
