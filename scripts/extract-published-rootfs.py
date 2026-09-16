#!/usr/bin/env python3
"""Extract the root partition of a verified compressed image without mounting."""
import gzip
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def extract(archive, inventory_path, destination):
    if destination.exists():
        raise ValueError(f"destination exists: {destination}")
    inventory = json.loads(inventory_path.read_text())
    if inventory.get("schema") != 1 or inventory.get("ownership_mode") != "buildroot":
        raise ValueError("unsupported image inventory")
    with tempfile.TemporaryDirectory(prefix="tdvp-rootfs-") as temporary:
        partition = Path(temporary) / "rootfs.ext4"
        with gzip.open(archive, "rb") as stream:
            stream.seek(512)
            header = stream.read(512)
            if header[:8] != b"EFI PART":
                raise ValueError("expected GPT image")
            entries_lba, count, size = struct.unpack_from("<QII", header, 72)
            if count > 1024 or size < 128 or size > 4096:
                raise ValueError("invalid GPT table")
            stream.seek(entries_lba * 512)
            entries = [stream.read(size) for _ in range(count)]
            candidates = []
            for entry in entries:
                name = entry[56:128].decode("utf-16-le").rstrip("\0")
                if name in ("rootfs", "root"):
                    candidates.append(struct.unpack_from("<QQ", entry, 32))
            if len(candidates) != 1:
                raise ValueError("expected one named rootfs GPT partition")
            first, last = candidates[0]
            remaining = (last - first + 1) * 512
            if first < 34 or remaining <= 0:
                raise ValueError("invalid rootfs bounds")
            stream.seek(first * 512)
            with partition.open("wb") as output:
                while remaining:
                    block = stream.read(min(1024 * 1024, remaining))
                    if not block:
                        raise ValueError("truncated rootfs")
                    output.write(block)
                    remaining -= len(block)
        destination.mkdir(parents=True)
        # The image is read-only. No loop device, sudo, or target executable.
        result = subprocess.run(["debugfs", "-R", f"rdump / {destination}", str(partition)],
                                stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        if result.returncode:
            raise ValueError(f"rootfs extraction failed: {result.stderr}")
    for name, record in inventory["files"].items():
        relative = Path(name.lstrip("/"))
        if not name.startswith("/") or ".." in relative.parts:
            raise ValueError(f"unsafe image path: {name}")
        path = destination / relative
        if record["type"] == "symlink":
            if not path.is_symlink() or os.readlink(path) != record["target"]:
                raise ValueError(f"image symlink differs: {name}")
        elif record["type"] == "file":
            if path.is_symlink() or not path.is_file() or digest(path) != record["sha256"]:
                raise ValueError(f"image file differs: {name}")
            path.chmod(record["mode"])
    print(f"verified published image: {len(inventory['files'])} inventory paths")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: extract-published-rootfs.py <image.gz> <inventory.json> <new-root>")
    extract(*(Path(argument).resolve() for argument in sys.argv[1:]))
