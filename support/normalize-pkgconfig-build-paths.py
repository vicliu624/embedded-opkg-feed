"""Remove declared build sysroot prefixes from generated pkg-config metadata."""
import argparse
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("install_root", type=Path)
parser.add_argument("--sysroot", type=Path, action="append", required=True)
parser.add_argument("--allow-missing-sysroot", action="store_true",
                    help="Normalize an explicitly declared absolute prefix from a removed producer work directory")
args = parser.parse_args()
root = args.install_root.resolve(strict=True)
if args.allow_missing_sysroot:
    assert all(path.is_absolute() for path in args.sysroot), "missing producer prefixes must be absolute"
prefixes = sorted({str(path.resolve(strict=not args.allow_missing_sysroot)).rstrip("/") for path in args.sysroot}, key=len, reverse=True)
assert all(prefix not in ("", "/", "/usr", "/lib") for prefix in prefixes)
changes = []
for path in sorted(root.rglob("*.pc")):
    assert not path.is_symlink(), path
    original = path.read_text()
    text = original
    for prefix in prefixes:
        text = re.sub(r"(?<!\S)-R" + re.escape(prefix) + r"/[^\s]+", "", text)
        text = text.replace(prefix + "/", "/")
        if prefix in text:
            raise SystemExit("Unresolved build sysroot in " + str(path))
    if text != original:
        changes.append((path, text))
for path, text in changes:
    path.write_text(text)
print("pkg-config build prefix normalization: PASS", len(changes), "files")
