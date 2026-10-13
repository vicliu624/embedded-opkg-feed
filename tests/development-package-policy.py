#!/usr/bin/env python3
"""Exercise development IPK boundaries and static object CPU0 validation."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
sdk = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="tdvp-development-policy-") as directory:
    work = Path(directory)
    metadata = (repo / "packages/eigen-dev/package.env").read_bytes()
    for name, relative, content in [
        ("header", "usr/include/fixture.h", b"int fixture(void);\n"),
        ("shared", "usr/lib/libfixture.so.1", b"forbidden runtime"),
        ("command", "usr/bin/fixture", b"forbidden command"),
        ("config", "etc/fixture.conf", b"forbidden system config"),
        ("elf-header", "usr/include/fixture.h", Path("/usr/bin/true").read_bytes()),
    ]:
        package = work / name
        payload = package / "root" / relative
        payload.parent.mkdir(parents=True)
        payload.write_bytes(content)
        (package / "package.env").write_bytes(metadata)
        result = subprocess.run(["bash", str(repo / "scripts/build-ipk.sh"),
                                 "--platform", "tdvp-k230-r1", str(package), str(work / (name + "-output"))],
                                capture_output=True, text=True)
        assert (result.returncode == 0) == (name == "header"), result.stdout + result.stderr
    package = work / "symlink"
    (package / "root/usr/include").mkdir(parents=True)
    (package / "root/usr/include/fixture.h").symlink_to("/etc/passwd")
    (package / "package.env").write_bytes(metadata)
    result = subprocess.run(["bash", str(repo / "scripts/build-ipk.sh"), "--platform", "tdvp-k230-r1",
                             str(package), str(work / "symlink-output")], capture_output=True, text=True)
    assert result.returncode != 0 and "symlinks" in result.stderr, result.stderr
    source = work / "fixture.c"
    source.write_text("int fixture(void) { return 1; }\n")
    foreign = work / "foreign/usr/lib"
    foreign.mkdir(parents=True)
    subprocess.run(["cc", "-c", str(source), "-o", str(work / "fixture.o")], check=True)
    subprocess.run(["ar", "rcs", str(foreign / "libfixture.a"), str(work / "fixture.o")], check=True)
    result = subprocess.run([sys.executable, str(repo / "scripts/verify-published-sdk-payload.py"),
                             str(sdk), str(foreign.parent.parent)], capture_output=True, text=True)
    assert result.returncode != 0 and "CPU0 RISC-V" in result.stderr, result.stderr
print("development package path, symlink, disguised ELF and foreign static object policy: PASS")
