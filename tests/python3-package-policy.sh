#!/usr/bin/env bash
# Keep CPython source-locked, directly cross-built, and split along stable
# ownership boundaries. Buildroot is a reviewed SDK/sysroot input, never the
# Python target-root payload source.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(cd -- "$script_dir/.." && pwd -P)
helper="$repo_root/support/python3-source-build.sh"
owner_map="$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
expected_archive='Python-3.13.3.tar.xz'
expected_sha='40f868bcbdeb8149a3149580bb9bfd407b3321cd48f0be631af955ac92c0e041'

expect_line() {
  local line=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Fqx "$line" <<<"$normalized" || {
    echo "missing CPython policy line in $path: $line" >&2
    exit 1
  }
}

expect_absent() {
  local pattern=$1 path=$2
  if grep -Eq -- "$pattern" "$path"; then
    echo "forbidden CPython policy pattern in $path: $pattern" >&2
    exit 1
  fi
}

bash -n "$helper" \
  "$repo_root/packages/libpython3.13/build.sh" \
  "$repo_root/packages/python3-runtime/build.sh" \
  "$repo_root/packages/python3/build.sh"

for package in libpython3.13 python3-runtime python3; do
  package_dir="$repo_root/packages/$package"
  expect_line "PACKAGE='$package'" "$package_dir/package.env"
  expect_line "PACKAGE_RELEASES='r10'" "$package_dir/package.env"
  expect_line "SOURCE_ARCHIVE='$expected_archive'" "$package_dir/package.env"
  expect_line "SOURCE_ARCHIVE_SHA256='$expected_sha'" "$package_dir/package.env"
  expect_line "UPSTREAM_NAME='CPython'" "$package_dir/source.lock"
  expect_line "UPSTREAM_VERSION='3.13.3'" "$package_dir/source.lock"
  expect_line "SOURCE_ARTIFACT_1_FILE='$expected_archive'" "$package_dir/source.lock"
  expect_line "SOURCE_ARTIFACT_1_SHA256='$expected_sha'" "$package_dir/source.lock"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" >/dev/null
done

expect_line "PACKAGE_BUILD_DEPENDS='libbz2 liblzma libz libncursesw libreadline libexpat-1 libffi-8 libmpdec-4 libsqlite3-0 libssl-3 libcrypto-3'" \
  "$repo_root/packages/libpython3.13/package.env"
expect_line "PACKAGE_DEPENDS='libpython3.13 (= 3.13.3-1), libbz2 (= 1.0.8-1), liblzma (= 5.6.4-1), libz (= 1.3.1-1), libncursesw (= 6.4-20230603-1), libreadline (= 8.2-1), libexpat-1 (= 2.7.0-1), libffi-8 (= 3.4.6-1), libmpdec-4 (= 4.0.0-1), libsqlite3-0 (= 3.48.0-1), libssl-3 (= 3.4.1-1), libcrypto-3 (= 3.4.1-1), ca-certificates (= 2025.02.1-1)'" \
  "$repo_root/packages/python3-runtime/package.env"
expect_line "PACKAGE_DEPENDS='python3-runtime (= 3.13.3-1)'" \
  "$repo_root/packages/python3/package.env"
expect_line 'libpython3.13.so.1.0|libpython3.13|3.13.3-1' "$owner_map"
if grep -Fq 'libpanelw.so.6|' "$owner_map"; then
  echo 'CPython must not enable _curses_panel until libpanelw has an admitted provider' >&2
  exit 1
fi

expect_line "TDVP_PYTHON3_VERSION='3.13.3'" "$helper"
expect_line "TDVP_PYTHON3_ARCHIVE_SHA256='$expected_sha'" "$helper"
expect_line "TDVP_PYTHON3_BUILD_INFO_DATE='Apr 08 2025'" "$helper"
expect_line "TDVP_PYTHON3_BUILD_INFO_TIME='13:54:08'" "$helper"
expect_line "TDVP_PYTHON3_SOURCE_DATE_EPOCH='1744120448'" "$helper"
expect_line '  [[ -f "$verifier" && ! -L "$verifier" ]] || {' "$helper"
expect_line '  mapfile -t rows < <(bash "$verifier" --package-dir "$package_dir" --emit-artifacts)' "$helper"
expect_line '      --with-system-expat \' "$helper"
expect_line '      --with-system-libmpdec \' "$helper"
expect_line '      --with-openssl-rpath=no \' "$helper"
expect_line '  buildinfo_source="$source_root/Modules/getbuildinfo.c"' "$helper"
expect_line "  grep -Fqx '#define DATE __DATE__' \"\$buildinfo_source\" &&" "$helper"
expect_line '    -e "s|^#define DATE __DATE__$|#define DATE \"$TDVP_PYTHON3_BUILD_INFO_DATE\"|" \' "$helper"
expect_line '    -e "s|^#define TIME __TIME__$|#define TIME \"$TDVP_PYTHON3_BUILD_INFO_TIME\"|" \' "$helper"
expect_line '    export SOURCE_DATE_EPOCH="$TDVP_PYTHON3_SOURCE_DATE_EPOCH"' "$helper"
expect_line '    export PYTHONHASHSEED=0' "$helper"
expect_line '    export CFLAGS="-ffile-prefix-map=$work_root=$reproducible_source_root -fdebug-prefix-map=$work_root=$reproducible_source_root -fmacro-prefix-map=$work_root=$reproducible_source_root"' "$helper"
expect_line "      find \"\$source_root\" -maxdepth 2 -type f -name '_sysconfigdata_*.py' -print | LC_ALL=C sort" "$helper"
expect_line '      sed -i "s|$work_root|$reproducible_source_root|g" "$sysconfig_source"' "$helper"
expect_line '        echo "CPython sysconfig still exposes the temporary build root: $sysconfig_source" >&2' "$helper"
expect_line 'format=2' "$helper"
expect_line 'build-info-date=$TDVP_PYTHON3_BUILD_INFO_DATE' "$helper"
expect_line 'build-info-time=$TDVP_PYTHON3_BUILD_INFO_TIME' "$helper"
expect_line 'source-date-epoch=$TDVP_PYTHON3_SOURCE_DATE_EPOCH' "$helper"
expect_line 'source-path=/usr/src/Python-$TDVP_PYTHON3_VERSION' "$helper"
expect_line 'sysconfig-paths=normalized' "$helper"
expect_line '    export py_cv_module__curses_panel=n/a' "$helper"
expect_line "    _ssl _hashlib _ctypes _decimal _sqlite3 _bz2 _lzma _curses readline" "$helper"
expect_line "    pyexpat _elementtree zlib binascii" "$helper"
expect_line '  rm -f -- "$install_root/usr/lib/python3.13/__pycache__"/pydoc.cpython-313*.pyc \' "$helper"
expect_line "    grep -Fqx 'system-expat=libexpat.so.1' \"\$marker\" &&" "$helper"
expect_line "    grep -Fqx 'curses-panel=disabled' \"\$marker\" || {" "$helper"
expect_line "    echo 'CPython pyexpat did not dynamically use the admitted libexpat.so.1 provider' >&2" "$helper"
expect_line "      echo 'python3-runtime must not publish _curses_panel without a libpanelw provider' >&2" "$helper"
expect_line 'tdvp_build_python3_source_stage "$package_dir" "$4" "${TDVP_PYTHON3_BUILDROOT_OUTPUT:-}"' \
  "$repo_root/packages/libpython3.13/build.sh"
expect_line 'tdvp_prepare_python_payload "$package_dir" libpython "$4"' \
  "$repo_root/packages/libpython3.13/build.sh"
expect_line 'tdvp_prepare_python_payload "$package_dir" runtime "$4"' \
  "$repo_root/packages/python3-runtime/build.sh"
expect_line 'tdvp_prepare_python_payload "$package_dir" cli "$4"' \
  "$repo_root/packages/python3/build.sh"
expect_absent 'tdvp_buildroot_install|--enable[[:space:]]+BR2_PACKAGE_PYTHON3' "$helper"
test ! -e "$repo_root/support/buildroot-python3.sh"

for path in "$repo_root/packages/libpython3.13/build.sh" \
  "$repo_root/packages/python3-runtime/build.sh" "$repo_root/packages/python3/build.sh"; do
  expect_absent 'tdvp_buildroot_install|BR2_PACKAGE_PYTHON3|/target/' "$path"
done
test -f "$repo_root/packages/python3/README.md"
grep -Fq 'never enables `BR2_PACKAGE_PYTHON3`' "$repo_root/packages/python3/README.md"
grep -Fq '`_curses_panel` off' "$repo_root/packages/python3/README.md"
grep -Fq 'pydoc' "$repo_root/packages/python3/README.md"

echo 'direct CPython source-build package policy: PASS'
