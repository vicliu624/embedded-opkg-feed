"""Exercise libpsl's private development projection with a real matching SDK."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
parser.add_argument("idn2_staging", type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
sdk = args.sdk.resolve(strict=True)
inputs = args.idn2_staging.resolve(strict=True)
assert (inputs / "usr/include/idn2.h").is_file()
before = {}
for path in sorted((sdk / "sysroot").rglob("*")):
    relative = path.relative_to(sdk).as_posix()
    if path.is_symlink():
        before[relative] = ("link", os.readlink(path))
    elif path.is_file():
        before[relative] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
with tempfile.TemporaryDirectory(prefix="tdvp-autotools-development-") as temporary:
    root = Path(temporary)
    fixture = root / "repo"
    fixture.mkdir()
    for name in ("support", "scripts", "platforms"):
        (fixture / name).symlink_to(repo / name, target_is_directory=True)
    package = fixture / "packages/libpsl"
    shutil.copytree(repo / "packages/libpsl", package, ignore=shutil.ignore_patterns("root", "__pycache__"))
    stage = root / "staging"
    stage.mkdir()
    env = dict(os.environ, TDVP_FEED_STAGING_ROOT=str(stage), TDVP_JOBS="2")
    command = ["bash", str(package / "build.sh"), "--platform", "tdvp-k230-r1", "--sdk-root", str(sdk)]
    missing = subprocess.run(command, env=env, capture_output=True, text=True)
    assert missing.returncode != 0 and "requested libidn2" in missing.stdout + missing.stderr, missing.stdout + missing.stderr
    shutil.copytree(inputs / "usr", stage / "usr", symlinks=True)
    present = subprocess.run(command, env=env, capture_output=True, text=True)
    assert present.returncode == 0, present.stdout + present.stderr
    assert (stage / "usr/lib/libpsl.so").exists()
    assert (stage / "usr/include/libpsl.h").is_file()
    generated = (package / "root").resolve(strict=True)
    assert generated.parent == Path("/tmp") and generated.name.startswith("tdvp-command-payload.")
    shutil.rmtree(generated)
after = {}
for path in sorted((sdk / "sysroot").rglob("*")):
    relative = path.relative_to(sdk).as_posix()
    if path.is_symlink():
        after[relative] = ("link", os.readlink(path))
    elif path.is_file():
        after[relative] = ("file", hashlib.sha256(path.read_bytes()).hexdigest())
assert before == after, "SDK sysroot changed"
print("Autotools feed development: PASS missing dependency rejected, provided dependency linked, complete SDK sysroot unchanged")
