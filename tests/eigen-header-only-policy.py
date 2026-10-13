"""Ensure the development-only Eigen recipe cannot enable optional native objects."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
hook = (repo / "packages/eigen-dev/build.sh").read_text()
for option in ("BUILD_TESTING", "EIGEN_BUILD_TESTING", "EIGEN_BUILD_BLAS",
               "EIGEN_BUILD_LAPACK", "EIGEN_BUILD_DEMOS", "EIGEN_BUILD_BTL",
               "EIGEN_BUILD_SPBENCH", "EIGEN_BUILD_DOC"):
    assert f"-D{option}=OFF" in hook, option
for option in ("EIGEN_BUILD_PKGCONFIG", "EIGEN_BUILD_CMAKE_PACKAGE"):
    assert f"-D{option}=ON" in hook, option
assert "'@development'" in hook
print("Eigen header-only build policy: PASS optional targets disabled, development interfaces retained")
