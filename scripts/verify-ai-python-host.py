"""Fail before compilation when the native AI Python builder is incomplete."""
import argparse
from importlib.metadata import PackageNotFoundError, version
import importlib
import os
from pathlib import Path
import platform
import re
import shutil
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--requirements", type=Path, default=Path(__file__).resolve().parents[1] /
                    "support/python-wheel-host-requirements.txt")
args = parser.parse_args()
if sys.version_info[:2] != (3, 13) or platform.machine() != "x86_64" or sys.platform != "linux":
    parser.exit(1, "AI builder requires native Linux x86_64 CPython 3.13; target Python and Ubuntu default 3.12 are not suitable\n")
for variable in ("_PYTHON_HOST_PLATFORM", "_PYTHON_SYSCONFIGDATA_NAME"):
    if os.environ.get(variable):
        parser.exit(1, "AI host preflight must run before exporting target sysconfig: " + variable + "\n")
count = 0
for line in args.requirements.read_text().splitlines():
    if not line.strip() or line.startswith("#"):
        continue
    match = re.fullmatch(r"([A-Za-z0-9_.-]+)==([^\s]+) --hash=sha256:([0-9a-f]{64})", line)
    if not match:
        parser.exit(1, "Host requirement lacks exact version/hash: " + line + "\n")
    try:
        actual = version(match[1])
    except PackageNotFoundError:
        parser.exit(1, "Missing pinned AI host distribution: " + match[1] + "\n")
    if actual != match[2]:
        parser.exit(1, "AI host tool version mismatch: " + match[1] + ": " + actual + ", required " + match[2] + "\n")
    count += 1
for module in ("ssl", "zlib", "bz2", "lzma", "ctypes", "pybind11", "pythran", "numpy"):
    importlib.import_module(module)
for executable in ("meson", "ninja", "cython", "pybind11-config", "pythran"):
    if shutil.which(executable) is None:
        parser.exit(1, "Missing AI host executable: " + executable + "\n")
print("Native AI Python host preflight: PASS", count, "pinned distributions and required modules/tools")
