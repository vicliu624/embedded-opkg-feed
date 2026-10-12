#!/usr/bin/env python3
"""Exercise bzip2 PREFIX links, portability, and fail-closed boundaries."""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

script = Path(__file__).resolve().parents[1] / "support/relativize-install-links.py"
builder = script.parent.parent / "scripts/build-all.sh"
source = builder.read_text()
gate = source.split("assert_staging_links_are_internal() {", 1)[1].split("\n}\n", 1)[0]
gate = "assert_staging_links_are_internal() {" + gate + "\n}\n"
with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    root = base / "install"
    commands = root / "usr/bin"
    commands.mkdir(parents=True)
    (commands / "bzgrep").write_bytes(b"fixture command\n")
    for name in ("bzegrep", "bzfgrep"):
        (commands / name).symlink_to(commands / "bzgrep")
    (commands / "existing").symlink_to("bzgrep")
    (commands / "chain").symlink_to(commands / "bzegrep")
    subprocess.run([sys.executable, str(script), str(root)], check=True)
    for name in ("bzegrep", "bzfgrep", "existing"):
        assert os.readlink(commands / name) == "bzgrep"
    copy = base / "relocated"
    shutil.copytree(root, copy, symlinks=True)
    shutil.rmtree(root)
    assert (copy / "usr/bin/bzegrep").read_bytes() == b"fixture command\n"
    assert os.readlink(copy / "usr/bin/chain") == "bzegrep"
    subprocess.run(["bash", "-c", gate + '\nassert_staging_links_are_internal "$1"',
                    "fixture", str(copy)], check=True)
    outside = base / "outside"
    outside.write_text("outside")
    for target in (str(outside), "../../../outside", "missing", "bad"):
        bad = copy / "usr/bin/bad"
        bad.symlink_to(target)
        result = subprocess.run([sys.executable, str(script), str(copy)], capture_output=True)
        assert result.returncode != 0, target
        assert os.readlink(bad) == target
        bad.unlink()
    # Invalid trees are rejected before rewriting any otherwise valid links.
    good = copy / "usr/bin/absolute"
    good.symlink_to(copy / "usr/bin/bzgrep")
    (copy / "usr/bin/bad").symlink_to("missing")
    result = subprocess.run([sys.executable, str(script), str(copy)], capture_output=True)
    assert result.returncode != 0
    assert os.path.isabs(os.readlink(good))
print("install-link-relocation: PASS")
