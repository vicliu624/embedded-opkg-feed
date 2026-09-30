#!/usr/bin/env python3
"""Verify historical names keep empty payloads and explicit provider identities."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
REFERENCES = {
    'libncursesw-6': ('libncursesw', 'libncursesw.so'),
    'libpcre2-8-0': ('libpcre2-8', 'libpcre2-8.so'),
    'libpopt-0': ('libpopt', 'libpopt.so'),
    'libreadline-8': ('libreadline', 'libreadline.so'),
    'libz-1': ('libz', 'libz.so'),
    'libresolv-2': ('tdvp-image-toolchain-external-custom', 'libresolv.so'),
    'libutil-1': ('tdvp-image-toolchain-external-custom', 'libutil.so'),
}


class HistoricalReferences(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix='tdvp-reference-policy-')
        self.addCleanup(temporary.cleanup)
        self.work = Path(temporary.name)
        self.repo = self.work / 'repo'
        (self.repo / 'support').mkdir(parents=True)
        (self.repo / 'packages').mkdir()
        for name in ('source-archive-library.sh', 'build-image-library-compat.sh'):
            shutil.copyfile(REPO / 'support' / name, self.repo / 'support' / name)
        for package in REFERENCES:
            shutil.copytree(REPO / 'packages' / package, self.repo / 'packages' / package,
                ignore=shutil.ignore_patterns('root'))
        self.image = self.work / 'image'
        (self.image / 'usr/lib').mkdir(parents=True)
        for provider, library in REFERENCES.values():
            (self.image / 'usr/lib' / (library + '.1')).write_bytes(b'inert test library')
        self.payloads = self.work / 'payloads'
        self.payloads.mkdir()
        self.environment = dict(os.environ, TDVP_FEED_BASE_ROOT=str(self.image), TMPDIR=str(self.payloads))

    def build(self, package):
        return subprocess.run(['bash', str(self.repo / 'packages' / package / 'build.sh'),
            '--platform', 'tdvp-k230-r1', '--sdk-root', str(self.work / 'sdk')],
            env=self.environment, capture_output=True, text=True)

    def test_all_historical_names_generate_empty_payloads(self):
        for package, (provider, library) in REFERENCES.items():
            with self.subTest(package=package):
                env = (self.repo / 'packages' / package / 'package.env').read_text()
                self.assertIn("PACKAGE_DEPENDS='" + provider + "'", env)
                self.assertIn("VERSION='2025.02.1-2'", env)
                self.assertIn("SOURCE_LOCK_EXEMPT_REASON='Empty compatibility reference;", env)
                result = self.build(package)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                payload = self.repo / 'packages' / package / 'root'
                self.assertTrue(payload.is_symlink())
                self.assertEqual(list(payload.iterdir()), [])
                # Repeat generation must remain empty and replace only generated roots.
                result = self.build(package)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertEqual(list(payload.iterdir()), [])

    def test_missing_image_library_fails_before_payload_generation(self):
        (self.image / 'usr/lib/libz.so.1').unlink()
        result = self.build('libz-1')
        self.assertEqual(result.returncode, 66, result.stdout + result.stderr)
        self.assertFalse((self.repo / 'packages/libz-1/root').exists())

    def test_wrong_provider_and_payload_mode_are_rejected(self):
        for setting in ("PACKAGE_DEPENDS='libreadline'", 'PACKAGE_IMAGE_REFERENCE_ONLY=0',
                        "LIBRARY_GLOB='../libz.so*'", "PACKAGE_BASE_OVERLAY='deny'"):
            with self.subTest(setting=setting):
                target = self.repo / 'packages/libz-1/package.env'
                original = target.read_text()
                target.write_text(original + '\n' + setting + '\n')
                result = self.build('libz-1')
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse((self.repo / 'packages/libz-1/root').exists())
                target.write_text(original)

    def test_existing_user_payload_is_preserved(self):
        payload = self.repo / 'packages/libz-1/root'
        payload.mkdir()
        (payload / 'user-file').write_bytes(b'preserve me')
        result = self.build('libz-1')
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((payload / 'user-file').read_bytes(), b'preserve me')

    def test_gba_transition_keeps_empty_payload_and_active_dependency(self):
        package = 'tdvp-cardputer-zero-gba-compat'
        shutil.copytree(REPO / 'packages' / package, self.repo / 'packages' / package,
            ignore=shutil.ignore_patterns('root'))
        metadata = (self.repo / 'packages' / package / 'package.env').read_text()
        self.assertIn("PACKAGE='tdvp-cardputer-zero-gba'", metadata)
        self.assertIn("VERSION='0.1.0-13'", metadata)
        self.assertIn("PACKAGE_RELEASES='r11'", metadata)
        self.assertIn("PACKAGE_DEPENDS='tdvp-gba'", metadata)
        result = self.build(package)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(list((self.repo / 'packages' / package / 'root').iterdir()), [])


if __name__ == '__main__':
    unittest.main(verbosity=2)
