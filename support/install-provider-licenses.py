"""Reuse verified same-version provider notices with explicit provenance."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("provider", type=Path)
parser.add_argument("package", type=Path)
parser.add_argument("payload", type=Path)
parser.add_argument("--provider-package", type=Path, required=True)
args = parser.parse_args()
provider = args.provider.resolve(strict=True)
package = args.package.resolve(strict=True)
payload = args.payload.resolve(strict=True)
metadata = (package / "package.env").read_text()
identity = re.search(r"^PACKAGE='([a-z0-9][a-z0-9+.-]*)'", metadata, re.M)
assert identity, "missing package identity"
name = identity[1]
lock = (package / "source.lock").read_bytes()
fields = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'", lock.decode(), re.M))
origin_bytes = (provider / "SOURCE.json").read_bytes()
origin = json.loads(origin_bytes)
provider_package = args.provider_package.resolve(strict=True)
provider_lock = (provider_package / "source.lock").read_bytes()
provider_identity = re.search(r"^PACKAGE='([a-z0-9][a-z0-9+.-]*)'",
                              (provider_package / "package.env").read_text(), re.M)
assert provider_identity and origin["package"] == provider_identity[1], "provider identity differs"
assert origin["source_lock_sha256"] == hashlib.sha256(provider_lock).hexdigest(), "provider source lock differs"
provider_fields = dict(re.findall(r"^([A-Z0-9_]+)='([^']*)'", provider_lock.decode(), re.M))
assert origin["declared_license"] == provider_fields["UPSTREAM_LICENSE"], "provider declaration differs"
assert origin["source"]["UPSTREAM_VERSION"] == provider_fields["UPSTREAM_VERSION"], "provider source version differs"
for key, value in provider_fields.items():
    if key.startswith("SOURCE_ARTIFACT_"):
        assert origin["source"].get(key) == value, "provider artifact differs: " + key
assert origin["schema"] == 1 and origin["declared_license"] == fields["UPSTREAM_LICENSE"], "provider license differs"
assert origin["source"]["UPSTREAM_VERSION"] == fields["UPSTREAM_VERSION"], "provider version differs"
assert re.fullmatch(r"[0-9a-f]{64}", origin["source_lock_sha256"]), "invalid provider source lock"
notices = origin["notice_sha256"]
assert notices, "provider has no verified notices"
expected = {}
for relative, digest in notices.items():
    part = PurePosixPath(relative)
    assert not part.is_absolute() and ".." not in part.parts and "\\" not in relative, "unsafe notice path"
    path = provider / relative
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(provider), "notice escapes provider"
    assert path.stat().st_size <= 16 * 1024 * 1024, "unexpected notice size"
    content = path.read_bytes()
    assert hashlib.sha256(content).hexdigest() == digest, "provider notice digest differs"
    expected[relative] = content
assert "SOURCE.json" not in expected, "reserved origin filename"
record = {"schema": 1, "package": name, "declared_license": fields["UPSTREAM_LICENSE"],
          "source_lock_sha256": hashlib.sha256(lock).hexdigest(), "notice_sha256": notices,
          "license_source": {"kind": "same-version-provider", "provider_origin": origin,
                             "provider_origin_sha256": hashlib.sha256(origin_bytes).hexdigest()}}
expected["SOURCE.json"] = (json.dumps(record, sort_keys=True, indent=2) + "\n").encode()
destination = payload / "usr/share/licenses" / name
assert destination.resolve().is_relative_to(payload), "destination escapes payload"
if destination.exists() or destination.is_symlink():
    assert destination.is_dir() and not destination.is_symlink(), "unsafe destination"
    actual = {p.relative_to(destination).as_posix(): p.read_bytes()
              for p in destination.rglob("*") if p.is_file() and not p.is_symlink()}
    assert actual == expected and not any(p.is_symlink() for p in destination.rglob("*")), "existing notices differ"
else:
    for relative, content in expected.items():
        path = destination / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        path.chmod(0o644)
print("Same-version provider license projection: PASS", name, len(notices), "notices")
