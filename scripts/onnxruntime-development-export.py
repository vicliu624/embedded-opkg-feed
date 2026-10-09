"""Project and verify the core inputs consumed by the ORT Python binding."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("mode", choices=("export", "verify"))
parser.add_argument("destination", type=Path)
parser.add_argument("--sdk", type=Path, required=True)
parser.add_argument("--package", type=Path, required=True)
parser.add_argument("--core-record", type=Path)
args = parser.parse_args()
sdk_digest = hashlib.sha256((args.sdk / "tdvp-sdk-manifest.json").read_bytes()).hexdigest()
lock_digest = hashlib.sha256((args.package / "source.lock").read_bytes()).hexdigest()
destination = args.destination.resolve()
if args.mode == "export":
    assert args.core_record is not None
    assert not destination.exists(), "refusing to overwrite development projection"
    record = json.loads(args.core_record.read_text())
    assert record["schema"] == 1 and record["rtti"] is True
    assert record["sdk_manifest_sha256"] == sdk_digest, "core SDK differs"
    core = Path(record["work"]).resolve(strict=True)
    source = Path((core / ".prepared").read_text().strip()).resolve(strict=True)
    assert source.is_relative_to(core / "source")
    cache = (core / "build/CMakeCache.txt").read_text()
    assert "onnxruntime_DISABLE_RTTI:BOOL=OFF" in cache.splitlines(), "RTTI core required"
    destination.mkdir(parents=True)
    (destination / "build").mkdir()
    for component in "session optimizer providers lora framework graph util mlas common flatbuffers".split():
        archive = core / ("build/libonnxruntime_" + component + ".a")
        assert archive.is_file() and not archive.is_symlink()
        shutil.copy2(archive, destination / "build" / archive.name)
    # Only binding inputs are projected, excluding object files, Ninja state,
    # private sysroots, compiler executables and unrelated build history.
    for subtree in ("include", "onnxruntime"):
        tree = source / subtree
        for path in tree.rglob("*"):
            assert not path.is_symlink(), "source projection contains symlink"
        shutil.copytree(tree, destination / "source" / subtree)
    shutil.copy2(source / "LICENSE", destination / "source/LICENSE")
    shutil.copy2(source / "ThirdPartyNotices.txt", destination / "source/ThirdPartyNotices.txt")
    for path in (core / "build").rglob("*"):
        if path.suffix not in (".h", ".hpp", ".inc"):
            continue
        assert path.is_file() and not path.is_symlink()
        relative = path.relative_to(core / "build")
        target = destination / "build" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
    (destination / "build/CMakeCache.txt").write_text("onnxruntime_DISABLE_RTTI:BOOL=OFF\n")
    files = {}
    for path in sorted(destination.rglob("*")):
        if path.is_file():
            files[path.relative_to(destination).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = {"schema": 1, "kind": "onnxruntime-binding-development", "rtti": True,
                "sdk_manifest_sha256": sdk_digest, "source_lock_sha256": lock_digest,
                "original_cmake_cache_sha256": hashlib.sha256(cache.encode()).hexdigest(), "files": files}
    (destination / "manifest.json").write_text(json.dumps(manifest, sort_keys=True, indent=2) + "\n")
else:
    manifest = json.loads((destination / "manifest.json").read_text())
    assert manifest["schema"] == 1 and manifest["kind"] == "onnxruntime-binding-development"
    assert manifest["rtti"] is True
    assert manifest["sdk_manifest_sha256"] == sdk_digest, "development SDK differs"
    assert manifest["source_lock_sha256"] == lock_digest, "development source differs"
    actual = {}
    for path in destination.rglob("*"):
        assert not path.is_symlink(), "development projection contains symlink"
        if path.is_file() and path != destination / "manifest.json":
            actual[path.relative_to(destination).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    assert actual == manifest["files"], "development projection bytes differ"
print("ORT development projection:", args.mode, "PASS", len(manifest["files"]), "files")
