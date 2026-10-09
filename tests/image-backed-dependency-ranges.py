"""Image projection must retain valid version range and alternative semantics."""
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / "scripts"))
from compose_image_backed_feed import rewrite_dependencies

packages = {"python3": {"fields": {"Version": "3.13.3-2"}}}
versions = {"python3": "3.13.3-2+img.test"}
image = {"tdvp-image-base": {"Version": "1+locked"}}
for operator in ("=", ">=", "<=", ">>", "<<", ">", "<"):
    actual = rewrite_dependencies(f"python3 ({operator} 3.13.3-2)", packages, versions, image)
    assert actual == f"python3 ({operator} 3.13.3-2+img.test)", actual
for expression in ("python3 (>= 3.12)", "python3 (< 3.14)", "python3 (<= 3.14)"):
    assert rewrite_dependencies(expression, packages, versions, image) == expression
assert rewrite_dependencies("python3 (>= 3.12) | alternative, tdvp-image-base", packages, versions, image) == (
    "python3 (>= 3.12) | alternative, tdvp-image-base (= 1+locked)"
)
for invalid in ("python3 (= 3.12)", "tdvp-image-base (>= 1+locked)", "tdvp-image-base (= 2+wrong)"):
    try:
        rewrite_dependencies(invalid, packages, versions, image)
    except ValueError:
        pass
    else:
        raise AssertionError("unsafe dependency rewrite accepted: " + invalid)
print("Image-backed exact/range dependency boundaries, alternatives and immutable image locks: PASS")
