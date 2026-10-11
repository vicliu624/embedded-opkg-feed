"""Link the target multilib consumer using only pkg-config private dependencies."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
parser.add_argument('staging', type=Path)
args = parser.parse_args()
sdk = args.sdk.resolve(strict=True)
stage = args.staging.resolve(strict=True)
repo = Path(__file__).resolve().parents[1]
environment = dict(os.environ, PKG_CONFIG_SYSROOT_DIR=str(stage),
                   PKG_CONFIG_LIBDIR=str(stage / 'usr/lib/pkgconfig'), PKG_CONFIG_PATH='')
flags = shlex.split(subprocess.check_output(['pkg-config', '--static', '--libs', 'x265'], env=environment, text=True))
assert '-pthread' in flags or '-lpthread' in flags, flags
# Explicit archive selects static x265; all transitive flags come from its .pc.
flags = [flag for flag in flags if flag != '-lx265']
with tempfile.TemporaryDirectory(prefix='tdvp-x265-pc-static-') as directory:
    executable = Path(directory) / 'consumer'
    subprocess.run([str(sdk / 'bin/riscv64-unknown-linux-gnu-g++'), '--sysroot=' + str(sdk / 'sysroot'),
                    '-I' + str(stage / 'usr/include'), str(repo / 'tests/x265-multilib-runtime-smoke.c'),
                    str(stage / 'usr/lib/libx265.a'), *flags, '-o', str(executable)], check=True)
    subprocess.run(['qemu-riscv64', '-L', str(sdk / 'sysroot'), str(executable)], check=True)
print('x265 pkg-config static consumer: PASS declared dependency closure for 8/10/12-bit APIs')
