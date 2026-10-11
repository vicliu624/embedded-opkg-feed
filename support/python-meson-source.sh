#!/usr/bin/env bash
# Cross-build Python extensions using the same CPython development projection.
tdvp_build_python_meson_source() (
  set -Eeuo pipefail
  local package_dir=$1 sdk_root=$2 module=$3
  shift 3
  source "$package_dir/../../scripts/feed-platform.sh"
  tdvp_assert_package_host_dependencies "$package_dir"
  source "$package_dir/../../support/source-archive-library.sh"
  source "$package_dir/../../support/elf-runtime-policy.sh"
  local stage=${TDVP_FEED_STAGING_ROOT:?} work source_root sysroot config payload elf temporary=1
  [[ -f "$stage/usr/include/python3.13/Python.h" ]] || {
    echo 'Python extension build requires exported CPython development files' >&2; exit 65;
  }
  if [[ -n ${TDVP_PYTHON_BUILD_CACHE_ROOT:-} ]]; then
    local cache_root=$TDVP_PYTHON_BUILD_CACHE_ROOT cache_key
    [[ ! -L "$cache_root" && "$PACKAGE" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || exit 70
    mkdir -p "$cache_root"
    cache_key=$({ sha256sum "$sdk_root/tdvp-sdk-manifest.json" "$package_dir/source.lock"; printf '%s\n' "$sdk_root"; } | sha256sum | cut -d' ' -f1)
    work="$cache_root/$PACKAGE-${cache_key:0:16}"
    [[ ! -L "$work" ]] || exit 70
    if [[ -e "$work" ]]; then
      [[ -f "$work/.tdvp-input-key" && "$(<"$work/.tdvp-input-key")" == "$cache_key" ]] || exit 70
    else
      mkdir "$work"
      printf '%s\n' "$cache_key" >"$work/.tdvp-input-key"
    fi
    temporary=0
  else
    work=$(mktemp -d /tmp/tdvp-python-meson.XXXXXX)
  fi
  trap 'rc=$?; if [[ $rc != 0 && -f "$work/build/meson-logs/meson-log.txt" ]]; then cat "$work/build/meson-logs/meson-log.txt" >&2; fi; if [[ $temporary == 1 ]]; then rm -rf -- "$work"; fi' EXIT
  mkdir -p "$work/source" "$work/sysroot" "$work/python-config"
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  cp -a "$stage/usr/." "$work/sysroot/usr/"
  sysroot="$work/sysroot"
  local -a configs=()
  mapfile -t configs < <(find "$stage/usr/lib/python3.13" -maxdepth 1 -name '_sysconfigdata*.py')
  [[ ${#configs[@]} == 1 ]] || { echo 'target Python sysconfig identity is ambiguous' >&2; exit 66; }
  config=${configs[0]}
  cp "$config" "$work/python-config/"
  # Meson's Python dependency resolver explicitly uses LIBPC and INCLUDEPY
  # from target sysconfig. Relocate development paths to the private sysroot;
  # preserve ABI fields, extension suffix and target data type information.
  python3 - "$work/python-config/${config##*/}" "$sysroot" <<'PY'
import ast, pathlib, sys
path, root = pathlib.Path(sys.argv[1]), sys.argv[2]
tree = ast.parse(path.read_text())
values = next(ast.literal_eval(node.value) for node in tree.body
              if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'build_time_vars' for t in node.targets))
for key in ['LIBPC', 'INCLUDEPY', 'CONFINCLUDEPY', 'LIBDIR', 'LIBPL']:
    value = values.get(key)
    if isinstance(value, str) and value.startswith('/usr/'):
        values[key] = root + value
for key in ['installed_base', 'installed_platbase', 'base', 'platbase', 'prefix', 'exec_prefix']:
    values[key] = root + '/usr'
path.write_text('build_time_vars = ' + repr(values) + '\n')
PY
  export _PYTHON_SYSCONFIGDATA_NAME=$(basename "$config" .py)
  export _PYTHON_HOST_PLATFORM=linux-riscv64
  export PYTHONPATH="$work/python-config"
  export PKG_CONFIG_SYSROOT_DIR="$sysroot"
  export PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
  export PKG_CONFIG_PATH=''
  # Paths are represented as Python literals, avoiding shell interpolation in
  # Meson's configuration syntax. No target binary is executed on the host.
  python3 - "$work/cross.ini" "$sdk_root" "$sysroot" "$module" <<'PY'
import pathlib, sys
out, sdk, root, module = sys.argv[1:]
flags = ['--sysroot=' + root, '-march=rv64imafdc_zicsr_zifencei', '-mabi=lp64d', '-O1', '-fPIC']
lines = ['[binaries]']
for name, executable in [('c','gcc'), ('cpp','g++'), ('ar','ar'), ('strip','strip')]:
    lines.append(name + ' = ' + repr(sdk + '/bin/riscv64-unknown-linux-gnu-' + executable))
if module == 'scipy':
    import pybind11
    lines.append('fortran = ' + repr(sdk + '/toolchain/bin/riscv64-unknown-linux-gnu-gfortran'))
lines += ["pkg-config = '/usr/bin/pkg-config'", '[host_machine]', "system = 'linux'", "cpu_family = 'riscv64'", "cpu = 'riscv64'", "endian = 'little'", '[properties]', 'needs_exe_wrapper = true', "longdouble_format = 'IEEE_QUAD_LE'"]
if module == 'scipy':
    lines += ['numpy-include-dir = ' + repr(root + '/usr/lib/python3.13/site-packages/numpy/_core/include'),
              'pybind11-include-dir = ' + repr(pybind11.get_include())]
lines += ['[built-in options]']
for name in ['c_args', 'cpp_args'] + (['fortran_args'] if module == 'scipy' else []):
    lines.append(name + ' = ' + repr(flags))
for name in ['c_link_args', 'cpp_link_args'] + (['fortran_link_args'] if module == 'scipy' else []):
    lines.append(name + ' = ' + repr(['--sysroot=' + root, '-Wl,-rpath-link,' + root + '/usr/lib']))
lines += ["python.platlibdir = 'lib/python3.13/site-packages'", "python.purelibdir = 'lib/python3.13/site-packages'"]
pathlib.Path(out).write_text('\n'.join(lines) + '\n')
PY
  local -a meson_command=(meson)
  if [[ "$module" == numpy ]]; then
    # NumPy 2.2 includes its required Meson feature-module implementation in
    # the hash-locked sdist. Stock Meson cannot configure that source release.
    [[ -f "$source_root/vendored-meson/meson/meson.py" ]] || exit 69
    meson_command=(python3 "$source_root/vendored-meson/meson/meson.py")
  fi
  local -a setup_options=()
  [[ ! -f "$work/build/build.ninja" ]] || setup_options+=(--reconfigure)
  "${meson_command[@]}" setup "$work/build" "$source_root" "${setup_options[@]}" --cross-file "$work/cross.ini" \
    --prefix=/usr --libdir=lib --buildtype=plain --wrap-mode=nodownload "$@"
  "${meson_command[@]}" compile -C "$work/build" -j "${TDVP_JOBS:-4}"
  DESTDIR="$work/install" "${meson_command[@]}" install -C "$work/build" --no-rebuild
  [[ -d "$work/install/usr/lib/python3.13/site-packages/$module" ]] || exit 67
  # Retain distribution identity in both runtime and development exports.
  source "$package_dir/source.lock"
  python3 "$package_dir/../../support/python-meson-runtime-metadata.py" \
    "$source_root" "$work/install" "$module" "$UPSTREAM_VERSION"
  payload=$(tdvp_prepare_generated_payload_root "$package_dir")
  mkdir -p "$payload/usr/lib/python3.13/site-packages"
  cp -a "$work/install/usr/lib/python3.13/site-packages/." "$payload/usr/lib/python3.13/site-packages/"
  while IFS= read -r -d '' elf; do
    "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" -h "$elf" | grep -Fq 'Machine:                           RISC-V' || exit 68
    tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$elf"
  done < <(find "$payload" -type f -name '*.so' -print0)
  mkdir -p "$stage/usr"
  cp -a "$work/install/usr/." "$stage/usr/"
  printf '%s\n' "$PACKAGE Python extension payload ready: $payload"
)
