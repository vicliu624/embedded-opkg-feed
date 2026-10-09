"""Fingerprint declared native CMake inputs before allowing cache reuse."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

package = Path(sys.argv[1]).resolve(strict=True)
destination = Path(sys.argv[2]).resolve()
expected = sys.argv[3]
options = sys.argv[4:]
repo = package.parents[1]
files = [package / "source.lock", package / "package.env",
         repo / "support/native-cmake-input.sh", repo / "support/source-archive-library.sh",
         Path(__file__).resolve()]
inputs = {str(path.relative_to(repo)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
dependencies = {}
for option in options:
    if option.startswith("-DCMAKE_PREFIX_PATH="):
        for value in option.split("=", 1)[1].split(";"):
            if not value:
                continue
            prefix = Path(value).resolve(strict=True)
            marker = prefix / ".tdvp-source-key"
            assert marker.is_file() and not marker.is_symlink(), "native dependency lacks source identity: " + str(prefix)
            dependencies[str(prefix)] = marker.read_text().strip()
record = {
    "schema": 2, "files": inputs, "destination": str(destination), "expected": expected,
    "options": options, "dependencies": dependencies,
    "host": Path("/etc/os-release").read_text(),
    "tools": {tool: subprocess.check_output([tool, "--version"], text=True)
              for tool in ("/usr/bin/gcc", "/usr/bin/g++", "cmake", "ninja")},
    "machine": subprocess.check_output(["/usr/bin/gcc", "-dumpmachine"], text=True),
}
print(hashlib.sha256(json.dumps(record, sort_keys=True).encode()).hexdigest())
