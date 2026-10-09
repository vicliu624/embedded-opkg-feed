#!/usr/bin/env python3
"""Apply the released SDK's CPU0 ELF policy to every new payload ELF."""
import filecmp
import importlib.util
from pathlib import Path
import sys
import subprocess
import tempfile

# Importing a verifier must not create __pycache__ inside the immutable SDK.
sys.dont_write_bytecode = True

sdk, payload = (Path(value).resolve() for value in sys.argv[1:3])
if not payload.is_dir():
    sys.exit(f"payload directory is missing: {payload}")
base = Path(sys.argv[3]).resolve() if len(sys.argv) == 4 else None
spec = importlib.util.spec_from_file_location("tdvp_sdk_verifier", sdk / "verify-sdk.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)
count = 0
archive_members = 0
for path in payload.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open("rb") as stream:
        magic = stream.read(8)
        if path.suffix == ".a" and magic != b"!<arch>\n":
            raise ValueError("static library must be a self-contained regular archive: " + str(path))
        if magic != b"!<arch>\n" and magic[:4] != b"\x7fELF":
            continue
    if magic == b"!<arch>\n":
        ar = sdk / "bin/riscv64-unknown-linux-gnu-ar"
        members = subprocess.check_output([ar, "t", path], text=True).splitlines()
        if not members or len(members) != len(set(members)):
            raise ValueError("static archive has no objects or ambiguous member names: " + str(path))
        with tempfile.TemporaryDirectory(prefix="tdvp-static-isa-") as directory:
            for number, member in enumerate(members):
                data = subprocess.check_output([ar, "p", path, member])
                if data[:4] != b"\x7fELF":
                    raise ValueError("static archive member is not an auditable ELF: " + str(path) + ": " + member)
                object_path = Path(directory) / (str(number) + ".o")
                object_path.write_bytes(data)
                verifier.verify_elf(sdk, object_path)
                archive_members += 1
        continue
    if base is not None:
        original = base / path.relative_to(payload)
        if original.is_file() and filecmp.cmp(path, original, shallow=False):
            continue
    verifier.verify_elf(sdk, path)
    count += 1
print(f"published SDK CPU0 policy: {count} new ELF files verified")
if archive_members:
    print(f"published SDK CPU0 static archive policy: {archive_members} object members verified")
