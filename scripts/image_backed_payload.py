#!/usr/bin/env python3
"""Plan image-backed payload references without changing either filesystem.

The caller must supply the image ownership manifest digest from its verified
platform lock. This plan is not itself an IPK, signature or release approval.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat


def file_record(path):
    mode = path.lstat().st_mode
    if stat.S_ISLNK(mode):
        return {"type": "symlink", "mode": stat.S_IMODE(mode), "target": os.readlink(path)}
    if stat.S_ISREG(mode):
        return {"type": "file", "mode": stat.S_IMODE(mode),
                "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    raise ValueError("unsupported payload object: " + str(path))


def plan_image_payload(payload_root, image_root, manifest_sha256):
    payload_root, image_root = Path(payload_root).resolve(), Path(image_root).resolve()
    if not payload_root.is_dir() or not image_root.is_dir():
        raise ValueError("payload and image roots must exist")
    if payload_root == image_root or payload_root.is_relative_to(image_root) or image_root.is_relative_to(payload_root):
        raise ValueError("payload and image roots must be separate")
    if not re.fullmatch(r"[0-9a-f]{64}", manifest_sha256):
        raise ValueError("a locked image manifest SHA256 is required")
    manifest_path = image_root / "usr/share/tdvp/opkg/image-base.json"
    if not manifest_path.resolve().is_relative_to(image_root):
        raise ValueError("image manifest escapes image root")
    manifest_bytes = manifest_path.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != manifest_sha256:
        raise ValueError("image manifest digest differs from platform lock")
    manifest = json.loads(manifest_bytes)
    image_files, new_files, owners, canonical_records = {}, {}, {}, {}
    for directory, directories, filenames in os.walk(payload_root, followlinks=False):
        for name in sorted(directories + filenames):
            source = Path(directory) / name
            relative = source.relative_to(payload_root)
            path = "/" + relative.as_posix()
            # Resolve parent directory aliases (e.g. /lib -> usr/lib), while
            # preserving the final symlink as an owned object in its own right.
            parent = (image_root / relative.parent).resolve()
            if not parent.is_relative_to(image_root):
                raise ValueError("image parent escapes root: " + path)
            target = parent / relative.name
            canonical = "/" + target.relative_to(image_root).as_posix()
            if source.is_dir() and not source.is_symlink():
                if os.path.lexists(target) and not target.is_dir():
                    raise ValueError("payload directory collides with image file: " + path)
                continue
            record = file_record(source)
            if canonical in canonical_records and canonical_records[canonical] != record:
                raise ValueError("payload aliases disagree: " + path)
            canonical_records[canonical] = record
            expected = manifest["files"].get(canonical)
            if expected is None:
                if os.path.lexists(target) or canonical in manifest["owners"]:
                    raise ValueError("image overlap lacks a file record: " + path)
                new_files[path] = record
                continue
            if not os.path.lexists(target) or file_record(target) != expected:
                raise ValueError("image file differs from locked inventory: " + path)
            if record != expected:
                raise ValueError("payload differs from image: " + path)
            owner = manifest["owners"].get(canonical)
            fields = manifest["installed_packages"].get(owner, {})
            version = fields.get("Version", "")
            if (not isinstance(owner, str) or not re.fullmatch(r"tdvp-image-[a-z0-9+.-]+", owner)
                    or fields.get("Package") != owner
                    or not re.fullmatch(r"[A-Za-z0-9.+:~_-]+", version)):
                raise ValueError("image overlap lacks a valid exact owner: " + path)
            owners[owner] = version
            image_files[path] = {"canonical_path": canonical, "owner": owner, "record": record}
    return {"schema": 1, "image_manifest_sha256": manifest_sha256,
            "image_files": dict(sorted(image_files.items())),
            "new_files": dict(sorted(new_files.items())),
            # Every owner is required. Combining them with OR loses coverage.
            "depends": [name + " (= " + version + ")" for name, version in sorted(owners.items())]}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--payload-root", required=True)
    parser.add_argument("--image-root", required=True)
    parser.add_argument("--image-manifest-sha256", required=True)
    args = parser.parse_args()
    try:
        plan = plan_image_payload(args.payload_root, args.image_root, args.image_manifest_sha256)
    except (ValueError, OSError, KeyError, TypeError) as error:
        parser.exit(1, str(error) + "\n")
    print(json.dumps(plan, indent=2, sort_keys=True))
