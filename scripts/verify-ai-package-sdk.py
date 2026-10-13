"""Reject incomplete platform SDKs before the full AI/common build starts."""
import argparse
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
args = parser.parse_args()
sdk = args.sdk.resolve(strict=True)
required = (
    "verify-sdk.py", "tdvp-sdk-manifest.json", "environment-setup.sh",
    "sysroot/usr/include/tdvp/tdvp_ai_abi.h",
    "sysroot/usr/include/sndfile.h", "sysroot/usr/lib/pkgconfig/sndfile.pc",
    "toolchain/bin/riscv64-unknown-linux-gnu-gfortran",
    "bin/riscv64-unknown-linux-gnu-gcc",
)
missing = [name for name in required if not (sdk / name).is_file()]
if missing:
    parser.exit(1, "AI package SDK is incomplete; missing: " + ", ".join(missing) + "\n")
gcc = subprocess.check_output([str(sdk / required[-1]), "-dumpversion"], text=True).strip()
fortran = subprocess.check_output([str(sdk / required[-2]), "-dumpversion"], text=True).strip()
if gcc != fortran:
    parser.exit(1, "C and Fortran compiler versions differ: " + gcc + "/" + fortran + "\n")
subprocess.run(["python3", str(sdk / "verify-sdk.py"), str(sdk), "--smoke"], check=True)
qemu = shutil.which("qemu-riscv64")
if qemu is None:
    parser.exit(1, "AI audio preflight requires qemu-riscv64\n")
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tdvp-ai-sdk-codecs-") as directory:
    binary = Path(directory) / "audio-codec-smoke"
    flags = shlex.split(subprocess.check_output(
        [str(sdk / "bin/pkg-config"), "--cflags", "--libs", "sndfile"], text=True))
    subprocess.run([str(sdk / "bin/riscv64-unknown-linux-gnu-gcc"), "-O1",
                    str(repo / "tests/ai-sdk-audio-codec-smoke.c"), "-o", str(binary),
                    "-Wl,-rpath-link," + str(sdk / "sysroot/usr/lib"), *flags, "-lm"], check=True)
    subprocess.run(["python3", str(repo / "scripts/verify-published-sdk-payload.py"),
                    str(sdk), directory], check=True)
    environment = dict(os.environ)
    for variable in ("LD_PRELOAD", "QEMU_SET_ENV", "QEMU_UNSET_ENV"):
        environment.pop(variable, None)
    environment["LD_LIBRARY_PATH"] = str(sdk / "sysroot/usr/lib") + ":" + str(sdk / "sysroot/lib")
    subprocess.run([qemu, "-L", str(sdk / "sysroot"), str(binary)], env=environment, check=True)
print("AI/common SDK preflight: PASS protocol, matching Fortran/C, WAV/FLAC and Vorbis/Opus capabilities")
