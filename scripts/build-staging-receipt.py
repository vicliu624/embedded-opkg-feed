"""Record and verify development staging bytes and their build input identity."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode", choices=("write", "verify"))
parser.add_argument("--repo", type=Path, required=True)
parser.add_argument("--sdk", type=Path, required=True)
parser.add_argument("--staging", type=Path, required=True)
parser.add_argument("--package", action="append", default=[])
args = parser.parse_args()
repo = args.repo.resolve(strict=True)
sdk = args.sdk.resolve(strict=True)
staging = args.staging.resolve(strict=True)
assert (staging / "usr").is_dir(), "staging has no development projection"
receipt_path = staging / "tdvp-build-staging-receipt.json"
previous = None
if args.mode == "verify":
    assert receipt_path.is_file() and not receipt_path.is_symlink(), "missing staging receipt"
    previous = json.loads(receipt_path.read_text())
    assert previous.get("schema") == 1 and isinstance(previous.get("packages"), list), "invalid staging receipt"
    assert 0 < len(previous["packages"]) <= 10000 and all(isinstance(p, str) for p in previous["packages"]), "invalid receipt package list"
    assert set(args.package) <= set(previous["packages"]), "requested provider absent from receipt"
    packages = sorted(set(previous["packages"]))
    assert len(packages) == len(previous["packages"]), "duplicate receipt package"
else:
    assert args.package, "write requires the complete built package closure"
    packages = sorted(set(args.package))
    assert len(packages) == len(args.package), "duplicate package receipt input"
inputs = {}
paths = list((repo / "support").rglob("*"))
paths += [p for p in (repo / "scripts").iterdir() if p.suffix in (".py", ".sh")]
for name in packages:
    assert re.fullmatch(r"[a-z0-9][a-z0-9+.-]*", name), "invalid package name"
    root = repo / "packages" / name
    assert (root / "package.env").is_file(), "missing package recipe: " + name
    paths += [root / part for part in ("package.env", "source.lock", "build.sh") if (root / part).exists()]
    for directory in ("src", "patches", "files"):
        if (root / directory).exists():
            paths += list((root / directory).rglob("*"))
for path in sorted(set(paths)):
    # Selection membership does not change how an existing provider was built.
    # Its own recipe and the shared compiler/build policies remain covered.
    if path == repo / "support/ai-common-library-cohort.json":
        continue
    if path.is_dir() or path.suffix == ".pyc" or "__pycache__" in path.parts:
        continue
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(repo), "unsafe build input"
    with path.open("rb") as stream:
        inputs[path.relative_to(repo).as_posix()] = hashlib.file_digest(stream, "sha256").hexdigest()
files = {}
for directory, subdirectories, filenames in os.walk(staging / "usr", followlinks=False):
    for name in sorted(subdirectories + filenames):
        path = Path(directory) / name
        if path.is_symlink():
            target = os.readlink(path)
            assert not target.startswith("/") and path.resolve(strict=True).is_relative_to(staging), "unsafe staging link"
            record = {"type": "symlink", "target": target}
        elif path.is_dir():
            continue
        else:
            assert path.is_file(), "unsupported staging object"
            with path.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            record = {"type": "file", "sha256": digest, "mode": path.stat().st_mode & 0o7777}
        files[path.relative_to(staging).as_posix()] = record
with (sdk / "tdvp-sdk-manifest.json").open("rb") as stream:
    sdk_identity = hashlib.file_digest(stream, "sha256").hexdigest()
receipt = {"schema": 1, "sdk_manifest_sha256": sdk_identity, "packages": packages,
           "build_inputs": inputs, "development_files": files}
path = receipt_path
if args.mode == "write":
    with path.open("x", encoding="utf-8") as stream:
        json.dump(receipt, stream, sort_keys=True, indent=2)
        stream.write("\n")
else:
    assert previous == receipt, "staging SDK, source/build inputs or development bytes differ"
print("Development staging receipt: PASS", args.mode, len(packages), "packages,", len(files), "paths")
