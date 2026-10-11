"""Retain locked sdist distribution metadata for a cross-built Meson module."""
import argparse
from email.parser import BytesParser
from email.policy import compat32
from pathlib import Path, PurePosixPath
import re
import shutil


def project_metadata(source, payload, module, version):
    if not re.fullmatch(r"[a-z0-9_]+", module) or not re.fullmatch(r"[0-9][A-Za-z0-9.+-]*", version):
        raise ValueError("unsafe Python distribution identity")
    source = source.resolve(strict=True)
    payload = payload.resolve(strict=True)
    site = payload / "usr/lib/python3.13/site-packages"
    if not site.resolve(strict=True).is_relative_to(payload):
        raise ValueError("site-packages escapes the payload root")
    if not (site / module).is_dir() or (site / module).is_symlink():
        raise ValueError("missing regular compiled module directory")
    info = source / "PKG-INFO"
    if info.is_symlink():
        raise ValueError("distribution metadata must be a regular source file")
    content = info.read_bytes()
    parsed = BytesParser(policy=compat32).parsebytes(content)
    if parsed.get("Name", "").lower().replace("-", "_") != module or parsed.get("Version") != version:
        raise ValueError("sdist metadata differs from locked module version")
    licenses = parsed.get_all("License-File", []) or ["LICENSE.txt"]
    reviewed = []
    for relative in licenses:
        path = PurePosixPath(relative)
        if path.is_absolute() or ".." in path.parts or "\\" in relative:
            raise ValueError("unsafe source license path")
        license_file = source / relative
        if license_file.is_symlink() or not license_file.is_file() or not license_file.resolve().is_relative_to(source):
            raise ValueError("source license is absent or escapes its archive")
        reviewed.append((relative, license_file))
    destination = site / (module + "-" + version + ".dist-info")
    wheel = ("Wheel-Version: 1.0\nGenerator: TDVP Meson package projection\n"
             "Root-Is-Purelib: false\nTag: cp313-cp313-linux_riscv64\n")
    if destination.is_dir() and not destination.is_symlink():
        expected = {"METADATA": content, "WHEEL": wheel.encode(), "top_level.txt": (module + "\n").encode()}
        expected.update({"licenses/" + relative: license_file.read_bytes() for relative, license_file in reviewed})
        actual = {path.relative_to(destination).as_posix(): path.read_bytes()
                  for path in destination.rglob("*") if path.is_file() and not path.is_symlink()}
        if actual == expected and not any(path.is_symlink() for path in destination.rglob("*")):
            print("Meson Python distribution metadata projection unchanged:", module, version)
            return
    if destination.exists() or destination.is_symlink():
        raise ValueError("refusing to overwrite existing distribution metadata")
    destination.mkdir()
    (destination / "METADATA").write_bytes(content)
    (destination / "WHEEL").write_text(wheel)
    (destination / "top_level.txt").write_text(module + "\n")
    for relative, license_file in reviewed:
        target = destination / "licenses" / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(license_file, target)
    print("Meson Python distribution metadata/license projection: PASS", module, version)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("payload", type=Path)
    parser.add_argument("module")
    parser.add_argument("version")
    arguments = parser.parse_args()
    project_metadata(arguments.source, arguments.payload, arguments.module, arguments.version)


if __name__ == "__main__":
    main()
