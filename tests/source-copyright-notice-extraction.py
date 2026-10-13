"""Check source notice extraction and reject traversal/symlink/overwrite inputs."""
from pathlib import Path
import subprocess
import tempfile

tool = Path(__file__).resolve().parents[1] / "support/extract-source-copyright-notices.py"
with tempfile.TemporaryDirectory(prefix="tdvp-copyright-test-") as directory:
    root = Path(directory)
    source = root / "source"
    source.mkdir()
    (source / "implementation.c").write_text("/* Copyright 2026 Fixture Authors. All rights reserved. */\nint example;\n")
    (source / "header.h").write_text("// SPDX-License-Identifier: BSD-2-Clause\nint example;\n")
    destination = source / "NOTICE"
    subprocess.run(["python3", str(tool), str(source), str(destination), "--file", "implementation.c", "--file", "header.h"], check=True)
    original = destination.read_bytes()
    assert b"Fixture Authors" in original and b"BSD-2-Clause" in original and b"int example" not in original
    outside = root / "outside.c"
    outside.write_text("/* Copyright sensitive fixture */\n")
    (source / "link.c").symlink_to(outside)
    for relative in ("../outside.c", str(outside), "link.c"):
        output = source / ("rejected-" + str(len(relative)))
        result = subprocess.run(["python3", str(tool), str(source), str(output), "--file", relative], capture_output=True, text=True)
        assert result.returncode != 0 and not output.exists()
    result = subprocess.run(["python3", str(tool), str(source), str(destination), "--file", "implementation.c"], capture_output=True, text=True)
    assert result.returncode != 0 and destination.read_bytes() == original
print("Source copyright notice extraction: PASS content, traversal/symlink rejection and no overwrite")
