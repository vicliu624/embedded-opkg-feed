#!/usr/bin/env python3
"""Apply the released SDK's CPU0 ELF policy to every new payload ELF."""
import filecmp
import importlib.util
from pathlib import Path
import sys

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
for path in payload.rglob("*"):
    if path.is_symlink() or not path.is_file():
        continue
    with path.open("rb") as stream:
        if stream.read(4) != b"\x7fELF":
            continue
    if base is not None:
        original = base / path.relative_to(payload)
        if original.is_file() and filecmp.cmp(path, original, shallow=False):
            continue
    verifier.verify_elf(sdk, path)
    count += 1
print(f"published SDK CPU0 policy: {count} new ELF files verified")
