"""Verify source-built HTTP/2 IPK identities, dependencies and license bytes."""
import argparse
from email.parser import BytesParser
import io
from pathlib import Path
import subprocess
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--ipks', type=Path, required=True)
parser.add_argument('--archives', type=Path, required=True)
args = parser.parse_args()
for name, version in (('h2', '4.4.1'), ('hpack', '4.2.0'), ('hyperframe', '6.1.0')):
    ipk = args.ipks / f'python3-{name}_{version}-1_riscv64.ipk'
    control = subprocess.check_output(['ar', 'p', str(ipk), 'control.tar.gz'])
    with tarfile.open(fileobj=io.BytesIO(control), mode='r:gz') as archive:
        member = next(m for m in archive if m.name.lstrip('./') == 'control')
        fields = BytesParser().parsebytes(archive.extractfile(member).read())
        assert fields['Package'] == 'python3-' + name and fields['Version'] == version + '-1'
        assert fields['Architecture'] == 'riscv64'
        assert 'python3 (>= 3.13.3-2)' in fields['Depends']
        if name == 'h2':
            assert 'python3-hpack (= 4.2.0-1)' in fields['Depends']
            assert 'python3-hyperframe (= 6.1.0-1)' in fields['Depends']
    with tarfile.open(args.archives / f'{name}-{version}.tar.gz', mode='r:gz') as archive:
        upstream_license = archive.extractfile(f'{name}-{version}/LICENSE').read()
    data = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        licenses = []
        metadata = None
        for member in archive:
            if not member.isfile():
                assert member.isdir(), 'unexpected symlink in pure Python wheel'
                continue
            content = archive.extractfile(member).read()
            assert not content.startswith(b'\x7fELF'), 'native object in pure Python provider'
            if Path(member.name).name == 'LICENSE':
                licenses.append(content)
            if member.name.endswith('.dist-info/METADATA'):
                metadata = BytesParser().parsebytes(content)
        assert licenses == [upstream_license], 'upstream license missing or changed'
        assert metadata and metadata['Name'] == name and metadata['Version'] == version
        requirements = metadata.get_all('Requires-Dist', [])
        if name == 'h2':
            assert set(requirements) == {'hpack<5,>=4.2', 'hyperframe<7,>=6.1'}
        else:
            assert not requirements, 'undeclared target dependency'
print('Python HTTP/2 IPKs: PASS exact controls, wheel runtime metadata, source license bytes and no native objects')
