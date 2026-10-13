"""Reject invalid upstream bootstrap paths through the real build hook."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
sdk = args.sdk.resolve(strict=True)
for command in ("autoreconf", "autoconf", "automake", "libtoolize"):
    assert shutil.which(command), command
with tempfile.TemporaryDirectory(prefix="tdvp-bootstrap-guard-") as directory:
    root = Path(directory)
    fixture = root / "repo"
    fixture.mkdir()
    for name in ("scripts", "support", "platforms"):
        (fixture / name).symlink_to(repo / name, target_is_directory=True)
    package = fixture / "packages/libcap-ng"
    shutil.copytree(repo / "packages/libcap-ng", package, ignore=shutil.ignore_patterns("root", "__pycache__"))
    metadata = (package / "package.env").read_text()
    stage = root / "stage"
    stage.mkdir()
    marker = root / "outside-was-executed"
    outside = root / "outside.sh"
    outside.write_text("#!/bin/sh\ntouch '" + str(marker) + "'\n")
    environment = dict(os.environ, TDVP_FEED_STAGING_ROOT=str(stage), TDVP_JOBS="2")
    command = ["bash", str(package / "build.sh"), "--platform", "tdvp-k230-r1", "--sdk-root", str(sdk)]
    control = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=180)
    assert control.returncode == 0, control.stdout + control.stderr
    generated = (package / "root").resolve(strict=True)
    assert generated.parent == Path("/tmp") and generated.name.startswith("tdvp-command-payload.")
    (package / "root").unlink()
    shutil.rmtree(generated)
    for invalid in ("../outside.sh", str(outside), "missing.sh", "file name.sh"):
        (package / "package.env").write_text(metadata + "\nPACKAGE_BOOTSTRAP_SCRIPT='" + invalid + "'\n")
        result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120)
        assert result.returncode != 0, (invalid, result.returncode, result.stdout, result.stderr)
        assert not marker.exists(), invalid
        assert not (package / "root").exists()
print("Autotools bootstrap guards: PASS traversal, absolute path, absent script and whitespace rejected before execution")
