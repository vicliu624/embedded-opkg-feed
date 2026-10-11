"""Verify third-pass installed versions, preserved XML ABI and target runtime tests."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("validation_root", type=Path)
parser.add_argument("installed_root", type=Path)
parser.add_argument("feed", type=Path)
args = parser.parse_args()
base, root, feed = (p.resolve(strict=True) for p in (args.validation_root, args.installed_root, args.feed))
candidate, installed = {}, {}
for path, target in ((feed / "Packages", candidate), (root / "var/lib/opkg/status", installed)):
    for block in path.read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if "Package" in fields and (target is candidate or fields.get("Status", "").endswith(" installed")):
            assert fields["Package"] not in target
            target[fields["Package"]] = fields["Version"]
for package in ("libev", "libjansson", "libzip", "libmnl", "libnftnl", "liblzo2", "libxml2-16", "libxslt"):
    assert installed.get(package) == candidate[package], (package, installed.get(package), candidate[package])
for soname in ("libev.so.4", "libjansson.so.4", "libzip.so.5", "libmnl.so.0", "libnftnl.so.11", "liblzo2.so.2", "libxml2.so.16", "libxslt.so.1", "libexslt.so.0"):
    assert (root / "usr/lib" / soname).exists(), soname
original = base / "ranged.38h5ew3r/image-root/usr/lib/libxml2.so.2"
preserved = root / "usr/lib/libxml2.so.2"
assert original.readlink() == preserved.readlink()
assert hashlib.file_digest(original.open("rb"), "sha256").digest() == hashlib.file_digest(preserved.open("rb"), "sha256").digest()
environment = dict(os.environ)
environment.pop("LD_LIBRARY_PATH", None)
environment.pop("QEMU_LD_PREFIX", None)
for relative in ("libev-source-build.h79teqk4/libev-runtime-smoke", "common-third-source-build.RDqdo9vA/common-third-runtime-smoke"):
    executable = base / relative
    assert executable.is_file(), relative
    subprocess.run(["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib"), str(executable)], cwd=root, env=environment, check=True, timeout=30)
parallel = base / "common-third-source-build.RDqdo9vA/xml-parallel-abi-smoke"
assert parallel.is_file()
for order in ("old-first", "new-first"):
    subprocess.run(["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib"), str(parallel), order], env=environment, check=True, timeout=15)
print("Installed third-pass interfaces: PASS eight exact versions, nine SONAMEs, old XML ABI bytes/link preserved, two load orders and target runtime programs")
