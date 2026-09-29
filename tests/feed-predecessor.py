#!/usr/bin/env python3
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
spec = importlib.util.spec_from_file_location('fetch_history', ROOT / 'scripts/fetch-feed-predecessor.py')
fetch = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)


class Predecessor(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        shutil.copytree(ROOT / 'site/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r2/riscv64', self.source)
        self.lock = self.root / 'lock.json'
        self.lock.write_text(json.dumps({'schema': 1, 'url': 'https://fixture.invalid/r2/riscv64',
                                        'index_sha256': hashlib.sha256((self.source / 'Packages').read_bytes()).hexdigest()}))
        self.downloads = []

    def run_fetch(self, cache=None):
        original = subprocess.run

        def run(command, **kwargs):
            if command[0] == 'curl':
                name = command[-3].rsplit('/', 1)[1]
                self.downloads.append(name)
                shutil.copyfile(self.source / name, command[-1])
                return subprocess.CompletedProcess(command, 0)
            return original(command, **kwargs)

        with patch.object(fetch.subprocess, 'run', side_effect=run):
            fetch.fetch_predecessor(self.lock, ROOT / 'keys/tdvp-repo-public.asc', self.root / 'output', cache)

    def test_signed_fixture_and_verified_cache(self):
        self.run_fetch(self.source)
        self.assertEqual(set(self.downloads), {'Packages', 'Packages.gz', 'Packages.asc', 'Packages.gz.asc'})
        for path in self.source.glob('*.ipk'):
            self.assertEqual(path.read_bytes(), (self.root / 'output' / path.name).read_bytes())

    def test_bad_index_hash_leaves_no_output(self):
        (self.source / 'Packages').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'index differs'):
            self.run_fetch()
        self.assertFalse((self.root / 'output').exists())

    def test_bad_signature_leaves_no_output(self):
        (self.source / 'Packages.asc').write_bytes(b'not a signature')
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_fetch()
        self.assertFalse((self.root / 'output').exists())

    def test_bad_package_leaves_no_output(self):
        next(self.source.glob('*.ipk')).write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'payload differs'):
            self.run_fetch()
        self.assertFalse((self.root / 'output').exists())

    def test_mutable_url_is_rejected(self):
        value = json.loads(self.lock.read_text())
        value['url'] = 'https://fixture.invalid/stable/riscv64'
        self.lock.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, 'immutable predecessor lock'):
            self.run_fetch()
        self.assertFalse(self.downloads)


if __name__ == '__main__':
    unittest.main(verbosity=2)
