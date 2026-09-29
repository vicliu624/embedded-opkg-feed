#!/usr/bin/env python3
"""Retrieve a hash-locked, signed immutable feed for upgrade history."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from urllib.parse import urlsplit

from compose_image_backed_feed import control_fields
from image_candidate_history import load_previous_candidate


def fetch_predecessor(lock_file, public_key, output, cache=None):
    lock = json.loads(Path(lock_file).read_text())
    url = lock['url']
    parsed = urlsplit(url)
    if (lock.get('schema') != 1 or parsed.scheme != 'https' or not parsed.hostname
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or not re.search(r'/r[1-9][0-9]*/riscv64$', parsed.path)
            or not re.fullmatch(r'[0-9a-f]{64}', lock['index_sha256'])):
        raise ValueError('invalid immutable predecessor lock')
    output = Path(output).absolute()
    if output.exists() or output.is_symlink():
        raise ValueError('predecessor output already exists')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.tdvp-history-', dir=output.parent) as temporary:
        work = Path(temporary)
        candidate = work / 'candidate'
        candidate.mkdir()

        def download(name):
            subprocess.run(['curl', '--fail', '--silent', '--show-error', '--location',
                            '--proto', '=https', '--proto-redir', '=https', '--retry', '2',
                            '--connect-timeout', '30', '--max-time', '600',
                            url + '/' + name, '--output', str(candidate / name)], check=True)

        for name in ('Packages', 'Packages.gz', 'Packages.asc', 'Packages.gz.asc'):
            download(name)
        index = (candidate / 'Packages').read_bytes()
        if hashlib.sha256(index).hexdigest() != lock['index_sha256']:
            raise ValueError('predecessor index differs from lock')
        if gzip.decompress((candidate / 'Packages.gz').read_bytes()) != index:
            raise ValueError('predecessor compressed index differs')
        keyring = work / 'public.gpg'
        subprocess.run(['gpg', '--batch', '--yes', '--dearmor', '--output', str(keyring), str(public_key)], check=True)
        for name in ('Packages', 'Packages.gz'):
            subprocess.run(['gpgv', '--keyring', str(keyring), str(candidate / (name + '.asc')),
                            str(candidate / name)], check=True)
        entries, names = [], set()
        for paragraph in index.decode().strip().split('\n\n'):
            entry = control_fields(paragraph, allow_projected=True)
            name = entry['Filename']
            if not re.fullmatch(r'[A-Za-z0-9_.+:~%-]+\.ipk', name) or '..' in name or name in names:
                raise ValueError('unsafe or duplicate predecessor filename')
            if not re.fullmatch(r'[0-9a-f]{64}', entry['SHA256sum']) or not entry['Size'].isdigit():
                raise ValueError('invalid predecessor package integrity fields')
            names.add(name)
            entries.append(entry)

        def fetch_package(entry):
            name = entry['Filename']
            cached = Path(cache) / name if cache else None
            if (cached and cached.is_file() and not cached.is_symlink()
                    and cached.stat().st_size == int(entry['Size'])
                    and hashlib.sha256(cached.read_bytes()).hexdigest() == entry['SHA256sum']):
                shutil.copyfile(cached, candidate / name)
            else:
                download(name)
            path = candidate / name
            if path.stat().st_size != int(entry['Size']) or hashlib.sha256(path.read_bytes()).hexdigest() != entry['SHA256sum']:
                raise ValueError('predecessor payload differs: ' + name)

        with ThreadPoolExecutor(max_workers=4) as executor:
            list(executor.map(fetch_package, entries))
        if any('X-TDVP-Image-Manifest-SHA256' in entry for entry in entries):
            download('image-backed-report.json')
        load_previous_candidate(candidate, control_fields)
        candidate.rename(output)
    print('verified signed predecessor: ' + str(output))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lock', required=True)
    parser.add_argument('--public-key', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--cache')
    args = parser.parse_args()
    fetch_predecessor(args.lock, args.public_key, args.output, args.cache)
