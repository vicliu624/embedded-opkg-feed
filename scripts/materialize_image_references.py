#!/usr/bin/env python3
"""Validate bound reference metadata and materialize only an isolated audit root.

Run index/IPK signature verification separately before trusting a public feed.
This tool never modifies an IPK or the supplied image filesystem.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil

from compose_image_backed_feed import control_fields
from image_backed_payload import file_record


def safe_relative(name):
    path = PurePosixPath(name)
    if (not isinstance(name, str) or not name.startswith("/") or name.startswith("//")
            or str(path) != name or ".." in path.parts or path == PurePosixPath("/")):
        raise ValueError("invalid reference path: " + str(name))
    return name.lstrip("/")


def materialize_references(control, payload_root, image_root, report_path, locked_digest):
    fields = control_fields(Path(control).read_text(), allow_projected=True)
    bound = fields.get("X-TDVP-Image-Manifest-SHA256")
    plan_digest = fields.get("X-TDVP-Image-Plan-SHA256")
    if not bound:
        if plan_digest:
            raise ValueError("reference plan has no image binding")
        return 0
    if not re.fullmatch(r"[0-9a-f]{64}", locked_digest) or bound != locked_digest:
        raise ValueError("reference requires matching locked image manifest digest")
    image, payload = Path(image_root).resolve(), Path(payload_root).resolve()
    if not image.is_dir() or not payload.is_dir() or image.is_relative_to(payload) or payload.is_relative_to(image):
        raise ValueError("audit payload and image must be separate directories")
    manifest_file = image / "usr/share/tdvp/opkg/image-base.json"
    if not manifest_file.resolve().is_relative_to(image):
        raise ValueError("manifest escapes image root")
    manifest_bytes = manifest_file.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != locked_digest:
        raise ValueError("image manifest differs from platform lock")
    manifest = json.loads(manifest_bytes)
    report = json.loads(Path(report_path).read_text())
    if report["schema"] != 1 or report["image_manifest_sha256"] != locked_digest:
        raise ValueError("reference report image identity differs")
    row = report["packages"][fields["Package"]]
    plan = row["plan"]
    if row["version"] != fields["Version"] or row["reused"]:
        raise ValueError("reference report package identity differs")
    if hashlib.sha256(json.dumps(plan, sort_keys=True).encode()).hexdigest() != plan_digest:
        raise ValueError("reference plan hash differs from package control")
    if plan["schema"] != 1 or plan["image_manifest_sha256"] != locked_digest:
        raise ValueError("reference plan image identity differs")
    # All remaining payload files must be accounted for. Metadata-only entries
    # must not smuggle an executable, a symlink or a second copy of a base file.
    actual = {}
    for directory, directories, files in os.walk(payload, followlinks=False):
        for name in directories + files:
            path = Path(directory) / name
            if path.is_dir() and not path.is_symlink():
                continue
            actual["/" + path.relative_to(payload).as_posix()] = file_record(path)
    if actual != plan["new_files"]:
        raise ValueError("remaining payload differs from reference plan")
    required, copies = {}, []
    for name, entry in plan["image_files"].items():
        relative = safe_relative(name)
        safe_relative(entry["canonical_path"])
        target = payload / relative
        if not target.parent.resolve().is_relative_to(payload) or os.path.lexists(target):
            raise ValueError("reference collides with payload or escapes audit root: " + name)
        source = (image / relative).parent.resolve() / Path(relative).name
        if not source.parent.is_relative_to(image):
            raise ValueError("reference parent escapes image root: " + name)
        canonical = "/" + source.relative_to(image).as_posix()
        if canonical != entry["canonical_path"]:
            raise ValueError("reference canonical path differs: " + name)
        expected = manifest["files"][canonical]
        if entry["record"] != expected or file_record(source) != expected:
            raise ValueError("reference file differs from locked image: " + name)
        owner = manifest["owners"][canonical]
        installed = manifest["installed_packages"][owner]
        if entry["owner"] != owner or installed["Package"] != owner:
            raise ValueError("reference owner differs: " + name)
        required[owner] = installed["Version"]
        copies.append((source, target))
    dependencies = [name + " (= " + version + ")" for name, version in sorted(required.items())]
    if plan["depends"] != dependencies:
        raise ValueError("reference owner dependency set differs")
    # Only a complete AND group provides a required owner. An OR alternative
    # could be bypassed and therefore cannot attest to these reference files.
    groups = {group.strip() for group in fields.get("Depends", "").split(",")}
    if not set(dependencies).issubset(groups):
        raise ValueError("reference lacks required exact owner dependencies")
    for source, target in sorted(copies, key=lambda pair: pair[1].as_posix()):
        target.parent.mkdir(parents=True, exist_ok=True)
        if not target.parent.resolve().is_relative_to(payload) or os.path.lexists(target):
            raise ValueError("reference target changed during materialization")
        shutil.copy2(source, target, follow_symlinks=False)
    return len(copies)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--control", required=True)
    parser.add_argument("--payload-root", required=True)
    parser.add_argument("--image-root", required=True)
    parser.add_argument("--report", required=True)
    parser.add_argument("--image-manifest-sha256", default="")
    args = parser.parse_args()
    try:
        count = materialize_references(args.control, args.payload_root, args.image_root,
                                       args.report, args.image_manifest_sha256)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, str(error) + "\n")
    if count:
        print("verified image reference files: " + str(count))
