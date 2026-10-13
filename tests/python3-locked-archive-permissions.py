"""Exercise the real CPython archive helper and verifier without execute bits."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--archive", type=Path, help="Also validate the genuine locked CPython archive")
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
production_hash = "40f868bcbdeb8149a3149580bb9bfd407b3321cd48f0be631af955ac92c0e041"
with tempfile.TemporaryDirectory(prefix="tdvp-python-archive-permissions-") as temporary:
    root = Path(temporary)
    repo = root / "repo"
    (repo / "scripts").mkdir(parents=True)
    package = repo / "packages/python3-runtime"
    package.mkdir(parents=True)
    for filename in ("package.env", "source.lock"):
        shutil.copyfile(source / "packages/python3-runtime" / filename, package / filename)
    verifier = repo / "scripts/verify-source-lock.sh"
    shutil.copyfile(source / "scripts/verify-source-lock.sh", verifier)
    verifier.chmod(0o644)
    assert not os.access(verifier, os.X_OK)
    cache = root / "cache"
    original_lock = (package / "source.lock").read_text()
    if args.archive:
        data = args.archive.read_bytes()
        assert hashlib.sha256(data).hexdigest() == production_hash
    else:
        # Fast CI fixture tests the mechanism. --archive keeps production
        # constants and source.lock unchanged for the real archive regression.
        data = b"test-only archive fixture\n"
    digest = hashlib.sha256(data).hexdigest()
    lock = original_lock.replace(production_hash, digest)
    (package / "source.lock").write_text(lock)
    archive = cache / "sha256" / digest / "Python-3.13.3.tar.xz"
    archive.parent.mkdir(parents=True)
    archive.write_bytes(data)
    command = ["bash", "-c",
               'source "$1"; TDVP_PYTHON3_ARCHIVE_SHA256=$3; tdvp_python3_locked_archive "$2"',
               "bash", str(source / "support/python3-source-build.sh"), str(package), digest]
    env = dict(os.environ, TDVP_SOURCE_CACHE_ROOT=str(cache))
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    assert result.returncode == 0 and result.stdout.strip() == str(archive), result.stdout + result.stderr
    verifier.rename(verifier.with_suffix(".saved"))
    missing = subprocess.run(command, env=env, capture_output=True, text=True)
    assert missing.returncode == 69 and "readable regular file" in missing.stderr
    verifier.with_suffix(".saved").rename(verifier)
    target = repo / "scripts/saved-verifier.sh"
    verifier.rename(target)
    verifier.symlink_to(target.name)
    linked = subprocess.run(command, env=env, capture_output=True, text=True)
    assert linked.returncode == 69
    verifier.unlink()
    target.rename(verifier)
    (package / "source.lock").write_text(lock.replace(digest, "0" * 64))
    wrong = subprocess.run(command, env=env, capture_output=True, text=True)
    assert wrong.returncode == 72, wrong.stdout + wrong.stderr
    (package / "source.lock").write_text(lock)
    archive.write_bytes(data + b"tampered")
    tampered = subprocess.run(command, env=env, capture_output=True, text=True)
    assert tampered.returncode == 74 and "archive hash differs" in tampered.stderr
print("CPython locked archive: PASS 0644 Bash verifier; missing/symlink verifier, wrong lock and tampered archive rejected",
      "(production archive)" if args.archive else "(fast fixture)")
