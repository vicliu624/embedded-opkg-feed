#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in libpython3.13 python3-runtime python3; do
  grep -Fqx "PACKAGE='$package'" "$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE_RELEASES='r9'" "$repo_root/packages/$package/package.env"
done
grep -Fqx 'libpython3.13.so.1.0|libpython3.13|3.13.3-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fq "PACKAGE_DEPENDS='libpython3.13 (= 3.13.3-1), libbz2 (= 1.0.8-1), liblzma (= 5.6.4-1), ca-certificates (= 2025.02.1-1)'" "$repo_root/packages/python3-runtime/package.env"
grep -Fq 'BR2_PACKAGE_PYTHON3_SSL' "$repo_root/support/buildroot-python3.sh"
grep -Fq 'BR2_PACKAGE_PYTHON3_SQLITE' "$repo_root/support/buildroot-python3.sh"
grep -Fq 'BR2_PACKAGE_PYTHON3_READLINE' "$repo_root/support/buildroot-python3.sh"
if grep -Eq 'cp .*libpython' "$repo_root/packages/python3-runtime/build.sh"; then
  echo 'python3-runtime must not duplicate public libpython' >&2
  exit 1
fi
