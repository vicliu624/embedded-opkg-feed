"""Collect reviewed source-header copyright/SPDX comments for binary notices."""
import argparse
from pathlib import Path, PurePosixPath
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("source", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--file", action="append", required=True)
args = parser.parse_args()
source = args.source.resolve(strict=True)
assert source.is_dir()
output = args.output.resolve()
assert output.is_relative_to(source) and not args.output.exists() and not args.output.is_symlink()
records = []
for relative in sorted(set(args.file)):
    part = PurePosixPath(relative)
    assert not part.is_absolute() and ".." not in part.parts and "\\" not in relative
    file = source / relative
    assert file.is_file() and not file.is_symlink() and file.resolve().is_relative_to(source)
    prefix = file.read_text()[:65536]
    blocks = [match.group() for match in re.finditer(r"/\*.*?\*/|//[^\n]*", prefix, re.S)
              if "copyright" in match.group().lower() or "SPDX-License-Identifier:" in match.group()]
    assert blocks, "No copyright/SPDX notice in reviewed source file: " + relative
    records.append(relative + "\n" + "\n".join(blocks))
content = ("Copyright and SPDX notices from the reviewed compiled component\n\n" + "\n\n".join(records) + "\n")
assert len(content.encode()) <= 16 * 1024 * 1024
with output.open("x", encoding="utf-8", newline="\n") as stream:
    stream.write(content)
print("Source copyright notice extraction: PASS", len(records), "reviewed files")
