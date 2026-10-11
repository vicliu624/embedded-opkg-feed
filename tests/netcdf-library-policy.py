"""Check scientific dataset provider and feature-preserving configuration."""
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
package = repo / 'packages/libnetcdf'
env = (package / 'package.env').read_text()
lock = (package / 'source.lock').read_text()
build = (package / 'build.sh').read_text()
assert "VERSION='4.10.1-1'" in env and "PACKAGE_LICENSE_FILES='COPYRIGHT'" in env
assert "PACKAGE_BUILD_DEPENDS='libhdf5 libbz2 libzstd'" in env
assert "SOURCE_ARTIFACT_1_SHA256='33c27231c478c3b35da7c7758fbdd02da1fe407abcb16ddfe195f69d164f930d'" in lock
assert 'no independent signature verified' in lock
for option in ('NETCDF_ENABLE_HDF5', 'NETCDF_ENABLE_DAP', 'NETCDF_ENABLE_NCZARR', 'NETCDF_ENABLE_REMOTE_FUNCTIONALITY'):
    assert '-D' + option + '=ON' in build
assert 'libnetcdf.so.22|libnetcdf|4.10.1-1' in (repo / 'platforms/tdvp-k230-r1/extra-runtime-owners.tsv').read_text()
assert json.loads((repo / 'support/ai-common-library-cohort.json').read_text())['groups']['scientific-netcdf-datasets'] == ['libnetcdf']
print('NetCDF policy: PASS archive identity, HDF5/DAP/NCZarr features and provider')
