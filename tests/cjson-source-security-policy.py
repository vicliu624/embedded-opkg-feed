"""Check cJSON source/patch identity before source build; runtime tests are separate."""
import hashlib
from pathlib import Path
import subprocess

repo = Path(__file__).resolve().parents[1]
directory = repo / "packages/libcjson"
metadata = (directory / "package.env").read_text()
assert "VERSION='1.7.19-2'" in metadata
host_dependencies = next(line for line in metadata.splitlines() if line.startswith("PACKAGE_HOST_DEPENDS=")).split("=", 1)[1].strip("'\"").split()
assert "patch" in host_dependencies
owners = (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines()
for soname in ("libcjson.so.1", "libcjson_utils.so.1"):
    assert f"{soname}|libcjson|1.7.19-2" in owners
patch = directory / "patches/0001-reject-json-pointer-index-overflow.patch"
assert patch.is_file() and not patch.is_symlink()
content = patch.read_text().replace("\r\n", "\n")
assert hashlib.sha256(content.encode()).hexdigest() == "2ba19ec00df72237f12a475838cbe7be1a8157c7d07f1a64a51d8d78016c0be8"
assert "parsed_index > (((size_t)-1) - digit) / 10" in content
assert "position == 0" in content
subprocess.run(["git", "apply", "--numstat", str(patch)], cwd=repo, check=True, stdout=subprocess.DEVNULL)
subprocess.run(["bash", str(repo / "scripts/verify-source-lock.sh"), "--package-dir", str(directory)], check=True)
print("cJSON source security policy: PASS source lock, patch identity/structure and runtime version ownership")
