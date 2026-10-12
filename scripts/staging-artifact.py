"""Transport development staging without losing POSIX links, names, or modes."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import tempfile


def digest(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inventory(root):
    result = {}
    for directory, subdirs, files in os.walk(root / "usr", followlinks=False):
        for name in sorted(subdirs + files):
            path = Path(directory) / name
            key = path.relative_to(root).as_posix()
            if path.is_symlink():
                target = os.readlink(path)
                if target.startswith("/") or not path.resolve(strict=True).is_relative_to(root):
                    raise ValueError("unsafe staging link: " + key)
                result[key] = {"type": "symlink", "target": target}
            elif path.is_dir():
                continue
            elif path.is_file():
                result[key] = {"type": "file", "sha256": digest(path),
                               "mode": path.stat().st_mode & 0o7777}
            else:
                raise ValueError("unsupported staging object: " + key)
    return result


def verify(root):
    receipt = root / "tdvp-build-staging-receipt.json"
    if receipt.is_symlink() or not receipt.is_file() or not (root / "usr").is_dir():
        raise ValueError("missing ordinary staging receipt or projection")
    data = json.loads(receipt.read_text())
    if data.get("schema") != 1 or inventory(root) != data["development_files"]:
        raise ValueError("staging transport differs from build receipt")


def checked_members(archive):
    members = archive.getmembers()
    names = set()
    links = set()
    for member in members:
        path = PurePosixPath(member.name)
        if (not member.name or path.is_absolute() or ".." in path.parts
                or path.as_posix() != member.name or "\\" in member.name
                or member.name in names):
            raise ValueError("unsafe or duplicate archive path: " + member.name)
        names.add(member.name)
        if not (member.isfile() or member.isdir() or member.issym()):
            raise ValueError("unsupported archive type: " + member.name)
        if member.mode & ~0o777:
            raise ValueError("unsafe archive mode: " + member.name)
        if member.issym():
            target = PurePosixPath(member.linkname)
            resolved = os.path.normpath(str(path.parent / target))
            if (target.is_absolute() or resolved == ".." or resolved.startswith("../")
                    or "\\" in member.linkname):
                raise ValueError("archive link escapes root: " + member.name)
            links.add(path)
    for member in members:
        if any(parent in links for parent in PurePosixPath(member.name).parents):
            raise ValueError("archive writes through a symlink: " + member.name)
    return members


def pack(root, output):
    if root.is_symlink() or not root.is_dir() or output.exists() or output.is_symlink():
        raise ValueError("pack requires ordinary staging and a new archive")
    root = root.resolve(strict=True)
    verify(root)
    if output.resolve().is_relative_to(root):
        raise ValueError("archive must be outside staging")
    with tarfile.open(output, "x:gz", dereference=False) as archive:
        # Recursive tar preserves directory links; clear inode tracking so
        # ordinary hard-linked files are transported as independent files.
        for directory, subdirs, files in os.walk(root, followlinks=False):
            for name in sorted(subdirs + files):
                path = Path(directory) / name
                archive.inodes.clear()
                archive.add(path, arcname=path.relative_to(root).as_posix(), recursive=False)
    with tarfile.open(output, "r:gz") as archive:
        checked_members(archive)
    output.with_name(output.name + ".sha256").write_text(digest(output) + "\n")
    print("staging artifact packed and validated")


def unpack(source, output):
    if source.is_symlink() or not source.is_file() or output.exists() or output.is_symlink():
        raise ValueError("unpack requires ordinary archive and new destination")
    checksum = source.with_name(source.name + ".sha256")
    if checksum.is_symlink() or not checksum.is_file() or checksum.read_text().strip() != digest(source):
        raise ValueError("staging archive checksum mismatch")
    with tempfile.TemporaryDirectory(prefix="tdvp-staging-transport-", dir=output.parent) as temporary:
        root = Path(temporary) / "projection"
        root.mkdir()
        with tarfile.open(source, "r:gz") as archive:
            members = checked_members(archive)
            # Paths, types, modes and link-parent writes were validated above.
            # Extract files and directories first, then links, without tar's
            # ownership restoration or version-dependent extraction filters.
            for member in sorted(members, key=lambda item: (item.name.count("/"), item.name)):
                path = root / member.name
                if member.isdir():
                    path.mkdir(parents=True, exist_ok=True)
                elif member.isfile():
                    path.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(member) as stream, path.open("xb") as dest:
                        shutil.copyfileobj(stream, dest)
                    path.chmod(member.mode)
            for member in members:
                if member.issym():
                    path = root / member.name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.symlink_to(member.linkname)
            for member in reversed(members):
                if member.isdir():
                    (root / member.name).chmod(member.mode)
        verify(root)
        root.rename(output)
    print("staging artifact restored: receipt bytes, links and modes match")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("pack", "unpack"))
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    {"pack": pack, "unpack": unpack}[args.mode](args.source, args.destination)
