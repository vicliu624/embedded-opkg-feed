"""Probe all Boost libraries without allowing host Python development fallback."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path)
parser.add_argument('sdk', type=Path)
parser.add_argument('staging', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
source = args.source.resolve(strict=True)
sdk = args.sdk.resolve(strict=True)
stage = args.staging.resolve(strict=True)
output = args.output.resolve()
assert '#define BOOST_VERSION 108200' in (source / 'boost/version.hpp').read_text()
assert (sdk / 'tdvp-sdk-manifest.json').is_file()
assert not output.exists()
output.mkdir()
subprocess.run(['bash', './bootstrap.sh', '--with-toolset=gcc'], cwd=source, check=True)
configuration = output / 'user-config.jam'
configuration.write_text(
    'using gcc : tdvp : ' + json.dumps(str(sdk / 'bin/riscv64-unknown-linux-gnu-g++')) + ' ;\n'
    'using python : 3.13 : /usr/bin/python3 : ' + json.dumps(str(stage / 'usr/include/python3.13')) +
    ' : ' + json.dumps(str(stage / 'usr/lib')) + ' ;\n')
compile_flags = ('--sysroot=' + str(sdk / 'sysroot') + ' -march=rv64imafdc -mabi=lp64d -O1 '
                 '-ffile-prefix-map=' + str(source) + '=/usr/src/tdvp/libboost -I' + str(stage / 'usr/include'))
link_flags = ('--sysroot=' + str(sdk / 'sysroot') + ' -march=rv64imafdc -mabi=lp64d '
              '-L' + str(stage / 'usr/lib') + ' -Wl,-rpath-link,' + str(stage / 'usr/lib'))
command = [str(source / 'b2'), '--ignore-site-config', '--user-config=' + str(configuration),
           '--build-dir=' + str(output / 'build'), '--stagedir=' + str(output / 'stage'),
           '-j2', 'toolset=gcc-tdvp', 'target-os=linux', 'architecture=riscv', 'address-model=64',
           'abi=sysv', 'binary-format=elf', 'threading=multi', 'link=shared', 'runtime-link=shared',
           'variant=release', 'cxxflags=' + compile_flags, 'linkflags=' + link_flags,
           '-sICU_PATH=' + str(sdk / 'sysroot/usr'), 'stage']
result = subprocess.run(command, cwd=source)
libraries = sorted(p.name for p in (output / 'stage/lib').glob('*.so*') if p.is_file())
(output / 'probe-report.json').write_text(json.dumps({
    'exit_code': result.returncode, 'libraries': libraries,
    'target_python_headers_present': (stage / 'usr/include/python3.13/Python.h').is_file(),
    'icu_headers_present': (sdk / 'sysroot/usr/include/unicode/utypes.h').is_file(),
    'command': command,
}, indent=2) + '\n')
print('Boost full cross-source probe result:', result.returncode, len(libraries), 'library paths', flush=True)
raise SystemExit(result.returncode)
