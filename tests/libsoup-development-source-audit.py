"""Audit existing libsoup headers against locked source and SDK generators.

This read-only audit is not a historical build receipt or an import authority.
Only disposable source/header generation occurs; runtime is not rebuilt.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
for name in ('archive', 'development', 'sdk', 'ipk'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
archive, development, sdk, ipk = (p.resolve(strict=True) for p in (args.archive, args.development, args.sdk, args.ipk))
archive_digest = hashlib.sha256(archive.read_bytes()).hexdigest()
assert archive_digest == '51ed0ae06f9d5a40f401ff459e2e5f652f9a510b7730e1359ee66d14d4872740'
sdk_digest = hashlib.sha256((sdk / 'tdvp-sdk-manifest.json').read_bytes()).hexdigest()
assert sdk_digest == 'cea9099600fe14fffefb0dae12dc3f81f9593d0e5affaaa603360747c9e45e6f'
headers = development / 'usr/include/libsoup-3.0/libsoup'
with tempfile.TemporaryDirectory(prefix='tdvp-soup-header-audit.') as directory:
    work = Path(directory)
    with tarfile.open(archive, mode='r:xz') as tar:
        tar.extractall(work, filter='data')
    source = work / 'libsoup-3.6.6'
    meson = (source / 'libsoup/meson.build').read_text()
    header_list = re.search(r'soup_introspection_headers\s*=\s*\[(.*?)\]', meson, re.S)[1]
    public = re.findall(r"'([^']+\.h)'", header_list)
    assert len(public) == 39 and len({Path(name).name for name in public}) == 39
    expected = {Path(name).name for name in public} | {'soup.h', 'soup-version.h', 'soup-enum-types.h'}
    actual = {p.name for p in headers.iterdir() if p.is_file() or p.is_symlink()}
    assert actual == expected, 'public header set changed'
    assert all(not (headers / name).is_symlink() for name in expected)
    for name in public:
        assert (source / 'libsoup' / name).read_bytes() == (headers / Path(name).name).read_bytes(), 'public source header changed: ' + name
    umbrella = (source / 'libsoup/soup.h').read_text()
    umbrella = re.sub(r'^#include "([^"]+)"$', lambda match: '#include <libsoup/' + Path(match[1]).name + '>', umbrella, flags=re.M)
    assert umbrella.encode() == (headers / 'soup.h').read_bytes(), 'installed umbrella transformation changed'
    generated_version = work / 'soup-version.h'
    subprocess.run([sys.executable, str(source / 'libsoup/generate-version-header.py'),
                    str(source / 'libsoup/soup-version.h.in'), str(generated_version), '3.6.6'], check=True)
    assert generated_version.read_bytes() == (headers / 'soup-version.h').read_bytes(), 'version generator output differs'
    generator = sdk / 'sysroot/usr/bin/glib-mkenums'
    assert generator.is_file() and not generator.is_symlink()
    assert hashlib.sha256(generator.read_bytes()).hexdigest() == '1762c04f4a316c85716c6985b61b20705974039fce8eff5f08fd557d652f6da8', 'SDK enum generator changed'
    enum_header = subprocess.check_output([sys.executable, str(generator), '--template',
                                          str(source / 'libsoup/soup-enum-types.h.template')]
                                         + [str(source / 'libsoup' / name) for name in public])
    assert enum_header == (headers / 'soup-enum-types.h').read_bytes(), 'SDK enum generator output differs'
subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / 'scripts/verify-staging-runtime-match.py'),
                '--staging', str(development), '--ipk', str(ipk), '--package', 'libsoup3', '--version', '3.6.6-1'], check=True)
print(json.dumps({'kind': 'tdvp-libsoup-public-development-audit', 'headers_verified': len(expected),
                  'source_archive_sha256': archive_digest, 'sdk_manifest_sha256': sdk_digest,
                  'sdk_enum_generator_sha256': hashlib.sha256(generator.read_bytes()).hexdigest(),
                  'import_authorized': False, 'historical_build_receipt': False}, sort_keys=True))
