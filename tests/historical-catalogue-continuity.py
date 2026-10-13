#!/usr/bin/env python3
import subprocess
from pathlib import Path
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/verify-historical-package-continuity.py'


class Continuity(unittest.TestCase):
    def run_gate(self, current, old=('old-app', 'old-library', 'libvvcam', 'tdvp-hello'), archive=True):
        with tempfile.TemporaryDirectory(prefix='tdvp-history-policy-') as directory:
            root = Path(directory)
            history = root / 'site/feed/platform/r1'
            history.mkdir(parents=True)
            candidate = root / 'candidate'
            candidate.mkdir()
            if archive:
                (history / 'Packages').write_text(''.join('Package: ' + x + '\n\n' for x in old))
            (candidate / 'Packages').write_text(''.join('Package: ' + x + '\n\n' for x in current))
            return subprocess.run([sys.executable, str(SCRIPT), '--repo-root', str(root),
                '--candidate', str(candidate)], capture_output=True, text=True)

    def test_preserves_supported_history_and_allows_additions(self):
        result = self.run_gate(('old-app', 'old-library', 'new-app'))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_missing_old_software_is_rejected(self):
        result = self.run_gate(('old-app',))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('old-library', result.stderr)

    def test_restoring_retired_camera_stack_is_rejected(self):
        result = self.run_gate(('old-app', 'old-library', 'libvvcam'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('retired names reintroduced', result.stderr)

    def test_missing_archived_evidence_is_rejected(self):
        result = self.run_gate(('old-app',), archive=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('no archived indices', result.stderr)


if __name__ == '__main__':
    unittest.main(verbosity=2)
