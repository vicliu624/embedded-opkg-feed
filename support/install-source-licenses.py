"""Project locked source license notices into an owned package payload."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("package", type=Path)
parser.add_argument("payload", type=Path)
parser.add_argument("--license-file", action="append", default=[])
args = parser.parse_args()
source = args.source.resolve(strict=True)
package = args.package.resolve(strict=True)
payload = args.payload.resolve(strict=True)
metadata = (package / "package.env").read_text()
identity = re.search(r"^PACKAGE='([a-z0-9][a-z0-9+.-]*)'", metadata, re.M)
assert identity, "missing safe package identity"
name = identity[1]
lock = package / "source.lock"
lock_bytes = lock.read_bytes()
fields = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'", lock_bytes.decode(), re.M))
assert fields.get("UPSTREAM_LICENSE"), "missing declared source license"
notices = args.license_file or [path.name for path in sorted(source.iterdir())
                               if re.fullmatch(r"(?:COPYING|LICEN[CS]E|NOTICE|COPYRIGHT)(?:[._-].*)?", path.name, re.I)
                               and path.is_file()]
assert notices, "no source license notices found; declare PACKAGE_LICENSE_FILES"
expected = {}
digests = {}
for relative in notices:
    part = PurePosixPath(relative)
    assert not part.is_absolute() and ".." not in part.parts and "\\" not in relative, "unsafe license path"
    path = source / relative
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(source), "license escapes source"
    assert path.stat().st_size <= 16 * 1024 * 1024, "unexpectedly large license notice"
    content = path.read_bytes()
    expected[relative] = content
    digests[relative] = hashlib.sha256(content).hexdigest()
origin = {"schema": 1, "package": name, "declared_license": fields["UPSTREAM_LICENSE"],
          "source_lock_sha256": hashlib.sha256(lock_bytes).hexdigest(), "notice_sha256": digests,
          "source": {key: value for key, value in fields.items()
                     if key.startswith("SOURCE_ARTIFACT_") or key in ("UPSTREAM_NAME", "UPSTREAM_VERSION", "UPSTREAM_REVISION")}}
assert "SOURCE.json" not in expected, "reserved origin filename"
expected["SOURCE.json"] = (json.dumps(origin, sort_keys=True, indent=2) + "\n").encode()
destination = payload / "usr/share/licenses" / name
assert destination.resolve().is_relative_to(payload), "license destination escapes payload"
if destination.exists() or destination.is_symlink():
    assert destination.is_dir() and not destination.is_symlink(), "unsafe existing license destination"
    actual = {path.relative_to(destination).as_posix(): path.read_bytes()
              for path in destination.rglob("*") if path.is_file() and not path.is_symlink()}
    assert actual == expected and not any(path.is_symlink() for path in destination.rglob("*")), "existing license contents differ"
else:
    for relative, content in expected.items():
        path = destination / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(0o644)
print("Source license notice projection: PASS", name, len(notices), "notices")
