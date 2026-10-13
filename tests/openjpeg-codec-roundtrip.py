"""Target lossless JPEG2000 roundtrip and truncated stream rejection."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
parser.add_argument('codec_bin', type=Path)
parser.add_argument('runtime_lib', type=Path)
parser.add_argument('work', type=Path)
args = parser.parse_args()
sdk, binaries, libraries = (p.resolve(strict=True) for p in (args.sdk, args.codec_bin, args.runtime_lib))
work = args.work.resolve()
assert not work.exists() and not work.is_symlink()
work.mkdir()
fixture = Path(__file__).with_name('openjpeg-lossless-input.pgm')
shutil.copy2(fixture, work / 'input.pgm')
prefix = ['qemu-riscv64', '-L', str(sdk / 'sysroot'), '-E', 'LD_LIBRARY_PATH=' + str(libraries)]
encode = subprocess.run(prefix + [str(binaries / 'opj_compress'), '-i', str(work / 'input.pgm'),
                                  '-o', str(work / 'encoded.j2k'), '-n', '2'], capture_output=True, timeout=30)
(work / 'encode.log').write_bytes(encode.stdout + encode.stderr)
assert encode.returncode == 0, encode.stderr.decode(errors='replace')
decode = subprocess.run(prefix + [str(binaries / 'opj_decompress'), '-i', str(work / 'encoded.j2k'),
                                  '-o', str(work / 'decoded.pgm')], capture_output=True, timeout=30)
(work / 'decode.log').write_bytes(decode.stdout + decode.stderr)
assert decode.returncode == 0, decode.stderr.decode(errors='replace')
data = (work / 'decoded.pgm').read_bytes()
header = re.match(rb'P5\s+(?:#[^\n]*\n\s*)*(\d+)\s+(\d+)\s+(\d+)\s', data)
assert header and tuple(map(int, header.groups())) == (4, 4, 255)
assert data[header.end():] == bytes(range(0, 256, 17))
(work / 'truncated.j2k').write_bytes((work / 'encoded.j2k').read_bytes()[:12])
rejected = subprocess.run(prefix + [str(binaries / 'opj_decompress'), '-i', str(work / 'truncated.j2k'),
                                    '-o', str(work / 'invalid.pgm')], capture_output=True, timeout=30)
(work / 'truncated.log').write_bytes(rejected.stdout + rejected.stderr)
assert rejected.returncode != 0 and not (work / 'invalid.pgm').exists()
print('OpenJPEG target codec: PASS 16 exact lossless pixels and truncated stream rejection without output')
