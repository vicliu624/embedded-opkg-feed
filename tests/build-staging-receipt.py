"""Exercise staging receipts without compiling or modifying real SDK inputs."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/build-staging-receipt.py"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    repo, sdk, stage = root / "repo", root / "sdk", root / "stage"
    for path in (repo / "support", repo / "scripts", repo / "packages/fixture/src",
                 sdk, stage / "usr/include"):
        path.mkdir(parents=True)
    helper = repo / "support/build.sh"
    helper.write_text("fixture build policy\n")
    metadata = repo / "packages/fixture/package.env"
    metadata.write_text("PACKAGE='fixture'\nVERSION='1.0-1'\n")
    source = repo / "packages/fixture/src/source.c"
    source.write_text("int fixture;\n")
    manifest = sdk / "tdvp-sdk-manifest.json"
    manifest.write_text('{"schema": 2}\n')
    header = stage / "usr/include/fixture.h"
    header.write_text("int fixture;\n")
    common = ["--repo", str(repo), "--sdk", str(sdk), "--staging", str(stage), "--package", "fixture"]
    subprocess.run([sys.executable, str(script), "write", *common], check=True, capture_output=True)
    verify = [sys.executable, str(script), "verify", *common]
    subprocess.run(verify, check=True, capture_output=True)
    (repo / "support/ai-common-library-cohort.json").write_text('{"new-consumer": true}\n')
    subprocess.run(verify, check=True, capture_output=True)
    assert subprocess.run(verify + ["--package", "missing-provider"], capture_output=True).returncode != 0
    cases = 0
    for path in (helper, metadata, source, manifest, header):
        content = path.read_bytes()
        path.write_bytes(content + b"changed\n")
        assert subprocess.run(verify, capture_output=True).returncode != 0, str(path)
        path.write_bytes(content)
        subprocess.run(verify, check=True, capture_output=True)
        cases += 1
    mode = header.stat().st_mode & 0o7777
    header.chmod(mode ^ 0o100)
    assert subprocess.run(verify, capture_output=True).returncode != 0
    header.chmod(mode)
    link = stage / "usr/include/escape.h"
    link.symlink_to("/etc/passwd")
    assert subprocess.run(verify, capture_output=True).returncode != 0
    link.unlink()
    header.unlink()
    assert subprocess.run(verify, capture_output=True).returncode != 0
    assert subprocess.run([sys.executable, str(script), "write", *common], capture_output=True).returncode != 0
    # A consumer may request one provider; verification still covers the
    # producer's complete recorded dependency closure.
    dependency = repo / "packages/dependency/src/dependency.c"
    dependency.parent.mkdir(parents=True)
    dependency.write_text("int dependency;\n")
    (dependency.parent.parent / "package.env").write_text("PACKAGE='dependency'\nVERSION='1.0-1'\n")
    second = root / "second-stage"
    (second / "usr/include").mkdir(parents=True)
    (second / "usr/include/fixture.h").write_text("int fixture;\n")
    closure = ["--repo", str(repo), "--sdk", str(sdk), "--staging", str(second)]
    subprocess.run([sys.executable, str(script), "write", *closure,
                    "--package", "fixture", "--package", "dependency"], check=True, capture_output=True)
    subset = [sys.executable, str(script), "verify", *closure, "--package", "fixture"]
    subprocess.run(subset, check=True, capture_output=True)
    dependency.write_text("changed dependency\n")
    assert subprocess.run(subset, capture_output=True).returncode != 0
print("Development receipt: PASS valid reuse and SDK/source/helper/data/mode/link/deletion/overwrite rejection")
