"""Run prepared RISC-V smoke executables against opkg-installed libraries."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("validation_root", type=Path)
parser.add_argument("installed_root", type=Path)
parser.add_argument("feed", type=Path)
args = parser.parse_args()
base = args.validation_root.resolve(strict=True)
root = args.installed_root.resolve(strict=True)
required = {
    "libbrotli": "1.2.0-1", "libcbor": "0.14.0-1", "libedit": "20260512-1",
    "libidn2": "2.3.8-1", "libpsl": "0.23.3-1", "librhash": "1.4.6-1", "libunwind": "1.8.3-1",
}
installed = {}
for block in (root / "var/lib/opkg/status").read_text().split("\n\n"):
    fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
    if fields.get("Status", "").endswith(" installed"):
        installed[fields["Package"]] = fields["Version"]
for name, version in required.items():
    candidate = {}
    for block in (args.feed / "Packages").read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if "Package" in fields:
            candidate[fields["Package"]] = fields["Version"]
    delivered = candidate[name]
    assert delivered == version or delivered.startswith(version + "+tdvpimg."), (name, delivered, version)
    assert installed.get(name) == delivered, (name, installed.get(name), delivered)
for soname in ("libbrotlienc.so.1", "libbrotlidec.so.1", "librhash.so.1", "libidn2.so.0", "libedit.so.0", "libcbor.so.0.14", "libpsl.so.5", "libunwind.so.8"):
    assert (root / "usr/lib" / soname).exists(), soname
executables = (
    "common-seven-runtime.BBSXJuGk/common-library-runtime-smoke",
    "libcbor-source-build.32AKJ6rf/libcbor-runtime-smoke",
    "libpsl-source-build.EU4wRotT/libpsl-runtime-smoke",
    "libunwind-source-build.O3VHeEGB/libunwind-runtime-smoke",
)
environment = dict(os.environ)
environment.pop("LD_LIBRARY_PATH", None)
environment.pop("QEMU_LD_PREFIX", None)
for relative in executables:
    executable = base / relative
    assert executable.is_file()
    subprocess.run(["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib"), str(executable)], env=environment, check=True, timeout=120)
print("Installed seven-library smoke: PASS exact opkg versions and all four RISC-V test programs")
