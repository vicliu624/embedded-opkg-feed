"""Exercise scalar target HTJ2K against a specified runtime provider."""
from pathlib import Path
import os
import re
import subprocess
import sys

sdk, codec, runtime, work = map(Path, sys.argv[1:])
for executable in ('ojph_compress/ojph_compress', 'ojph_expand/ojph_expand'):
    dynamic = subprocess.check_output([str(sdk / 'bin/riscv64-unknown-linux-gnu-readelf'), '-d', str(codec / executable)], text=True)
    assert 'Shared library: [libpthread.so.0]' in dynamic, 'Codec fixture must explicitly link pthread on the glibc 2.33 platform'
work.mkdir(parents=True, exist_ok=False)
pixels = bytes(range(64))
source = work / 'input.pgm'
source.write_bytes(b'P5\n8 8\n255\n' + pixels)
prefix = ['qemu-riscv64', '-L', str(sdk / 'sysroot'), '-E', f'LD_LIBRARY_PATH={runtime}']
env = dict(os.environ)
env.pop('LD_LIBRARY_PATH', None)
subprocess.run(prefix + [str(codec / 'ojph_compress/ojph_compress'), '-i', str(source), '-o', str(work / 'encoded.j2c'), '-reversible', 'true', '-num_decomps', '1'], env=env, check=True, timeout=30)
subprocess.run(prefix + [str(codec / 'ojph_expand/ojph_expand'), '-i', str(work / 'encoded.j2c'), '-o', str(work / 'output.pgm')], env=env, check=True, timeout=30)
decoded = (work / 'output.pgm').read_bytes()
header = re.match(rb'P5\s+8\s+8\s+255\s', decoded)
assert header and decoded[header.end():] == pixels
bad = work / 'truncated.j2c'
bad.write_bytes((work / 'encoded.j2c').read_bytes()[:12])
failure = subprocess.run(prefix + [str(codec / 'ojph_expand/ojph_expand'), '-i', str(bad), '-o', str(work / 'invalid.pgm')], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
assert failure.returncode != 0
print('OpenJPH target HTJ2K reversible pixels and truncated-input rejection: PASS')
