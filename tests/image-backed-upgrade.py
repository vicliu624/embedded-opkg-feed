#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import unittest

spec = importlib.util.spec_from_file_location('composition_fixture', Path(__file__).with_name('image-backed-compose.py'))
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
from image_candidate_history import projected_version


class Upgrade(unittest.TestCase):
    def setUp(self):
        self.fixture = fixture.Compose()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.f = self.fixture

    def compose(self, name, previous=None):
        output = self.f.work / name
        fixture.compose_image_backed_feed(self.f.source, self.f.image, self.f.digest, output, previous)
        return output

    def change_dependency(self):
        staging = self.f.work / 'staging-libbase'
        control = staging / 'control/control'
        control.write_text(control.read_text().replace('Description: test', 'Description: changed'))
        (staging / 'control.tar.gz').write_bytes(fixture.archive_directory(staging / 'control'))
        subprocess.run(['ar', 'rD', str(self.f.source / 'libbase_1-1_riscv64.ipk'), 'control.tar.gz'], cwd=staging, check=True)

    def test_identity_decrease_still_increases_revision(self):
        old_hash, new_hash = 'f' * 64, '0' * 64
        old_version = '1-1+tdvpimg.9.' + old_hash[:20]
        previous = {'fields': {'Version': old_version, 'X-TDVP-Image-Manifest-SHA256': self.f.digest,
                              'X-TDVP-Composition-Identity': old_hash, 'X-TDVP-Composition-Revision': '9',
                              'X-TDVP-Source-Version': '1-1'}}
        version, revision, reused = projected_version('1-1', new_hash, previous)
        self.assertEqual(revision, 10)
        self.assertFalse(reused)
        self.assertEqual(subprocess.run(['dpkg', '--compare-versions', version, 'gt', old_version]).returncode, 0)

    def test_unchanged_history_and_unrelated_package_preserve_bytes(self):
        first = self.compose('first')
        self.f.make_package('unrelated', 'usr/bin/unrelated', b'unrelated')
        second = self.compose('second', first)
        for path in first.glob('*.ipk'):
            self.assertEqual(path.read_bytes(), (second / path.name).read_bytes())

    def test_changed_dependency_increments_consumer_and_provider(self):
        first = self.compose('first')
        self.change_dependency()
        second = self.compose('second', first)
        for name in ('libbase', 'consumer'):
            old = self.f.fields(next(first.glob(name + '_*.ipk')))
            new = self.f.fields(next(second.glob(name + '_*.ipk')))
            self.assertEqual(old['X-TDVP-Composition-Revision'], '1')
            self.assertEqual(new['X-TDVP-Composition-Revision'], '2')
            self.assertEqual(subprocess.run(['dpkg', '--compare-versions', new['Version'], 'gt', old['Version']]).returncode, 0)
        self.assertEqual((first / 'independent_1-1_riscv64.ipk').read_bytes(),
                         (second / 'independent_1-1_riscv64.ipk').read_bytes())

    def test_previous_report_tampering_is_rejected(self):
        first = self.compose('first')
        report = first / 'image-backed-report.json'
        content = json.loads(report.read_text())
        content['packages']['consumer']['plan']['new_files'] = {}
        report.write_text(json.dumps(content))
        with self.assertRaisesRegex(ValueError, 'report differs'):
            self.compose('second', first)
        self.assertFalse((self.f.work / 'second').exists())

    def test_previous_package_tampering_is_rejected(self):
        first = self.compose('first')
        path = next(first.glob('consumer_*.ipk'))
        path.write_bytes(path.read_bytes() + b'tamper')
        with self.assertRaisesRegex(ValueError, 'size or path differs'):
            self.compose('second', first)

    def test_dropping_previous_package_is_rejected(self):
        first = self.compose('first')
        (self.f.source / 'independent_1-1_riscv64.ipk').unlink()
        with self.assertRaisesRegex(ValueError, 'previous packages missing'):
            self.compose('second', first)

    def test_source_downgrade_is_rejected(self):
        identity = 'f' * 64
        previous = {'fields': {'Version': '2-1+tdvpimg.1.' + identity[:20],
                              'X-TDVP-Image-Manifest-SHA256': self.f.digest,
                              'X-TDVP-Composition-Identity': identity,
                              'X-TDVP-Composition-Revision': '1', 'X-TDVP-Source-Version': '2-1'}}
        with self.assertRaisesRegex(ValueError, 'source version downgrade'):
            projected_version('1-1', '0' * 64, previous)

    def test_first_migration_from_plain_version_increases(self):
        version, revision, reused = projected_version('1-1', 'a' * 64, {'fields': {'Version': '1-1'}})
        self.assertEqual(revision, 1)
        self.assertFalse(reused)
        self.assertEqual(subprocess.run(['dpkg', '--compare-versions', version, 'gt', '1-1']).returncode, 0)

    def test_hash_only_experimental_history_is_rejected(self):
        previous = {'fields': {'Version': '1-1+tdvpimg.' + 'a' * 20,
                              'X-TDVP-Image-Manifest-SHA256': self.f.digest}}
        with self.assertRaisesRegex(ValueError, 'experimental hash-only'):
            projected_version('1-1', 'b' * 64, previous)

    @unittest.skipUnless(os.environ.get('TDVP_TEST_OPKG'), 'requires native opkg')
    def test_real_upgrade_preserves_held_base(self):
        first = self.compose('first')
        self.change_dependency()
        second = self.compose('second', first)
        database = self.f.image / 'var/lib/opkg'
        (database / 'info').mkdir(parents=True)
        (database / 'lists').mkdir()
        status = database / 'status'
        status.write_text('Package: tdvp-image-base-lib\nVersion: 1+locked\nArchitecture: riscv64\n'
                          'Status: install hold installed\nEssential: yes\n\n')
        owner = database / 'info/tdvp-image-base-lib.list'
        owner.write_text('/usr/lib/libbase.so.1\n')
        config = self.f.work / 'opkg.conf'
        command = [os.environ['TDVP_TEST_OPKG'], '-f', str(config), '-o', str(self.f.image)]
        for feed, action in ((first, 'install'), (second, 'upgrade')):
            config.write_text('dest root /\noption lists_dir /var/lib/opkg/lists\n'
                              'option info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n'
                              'arch riscv64 10\nsrc test ' + feed.as_uri() + '\n')
            (database / 'lists/test').write_bytes((feed / 'Packages').read_bytes())
            result = subprocess.run(command + [action, 'consumer'], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for name in ('consumer', 'libbase'):
                fields = self.f.fields(next(feed.glob(name + '_*.ipk')))
                self.assertIn('Version: ' + fields['Version'] + '\n', status.read_text())
            self.assertEqual((self.f.image / 'usr/lib/libbase.so.1').read_bytes(), b'base-library')
            self.assertEqual(owner.read_text(), '/usr/lib/libbase.so.1\n')
            self.assertIn('Status: install hold installed', status.read_text())
            self.assertIn('Essential: yes', status.read_text())
        for name in ('consumer', 'libbase'):
            result = subprocess.run(command + ['remove', name], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.f.image / 'usr/lib/libbase.so.1').read_bytes(), b'base-library')


if __name__ == '__main__':
    unittest.main(verbosity=2)
