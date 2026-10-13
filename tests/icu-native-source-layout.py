#!/usr/bin/env python3
"""Exercise native ICU preparation without compiling ICU or downloading inputs."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class IcuNativeSourceLayout(unittest.TestCase):
    def test_native_configure_receives_original_parent_license(self):
        with tempfile.TemporaryDirectory(prefix="tdvp-icu-layout-") as directory:
            root = Path(directory)
            support = root / "support"
            package = root / "packages/libicuuc"
            support.mkdir()
            package.mkdir(parents=True)
            source = root / "locked-icu/source"
            source.mkdir(parents=True)
            license_bytes = b"Locked upstream ICU license fixture\n"
            (source.parent / "LICENSE").write_bytes(license_bytes)
            configure = source / "configure"
            configure.write_text(
                '#!/bin/bash\nset -eu\n'
                'cmp "$(dirname "$0")/../LICENSE" "$EXPECTED_LICENSE"\n'
                'printf "native-source-layout-verified\\n"\nexit 73\n'
            )
            configure.chmod(0o755)
            shutil.copyfile(REPO / "support/published-native-inputs.sh", support / "published-native-inputs.sh")
            (support / "source-archive-library.sh").write_text(
                'tdvp_unpack_locked_source_archive() { printf "%s\\n" "$FIXTURE_SOURCE"; }\n'
            )
            result = subprocess.run(
                ["bash", "-c", 'source "$1"; tdvp_sdk_icu_inputs "$2" "$3"',
                 "icu-layout-test", str(support / "published-native-inputs.sh"), str(package), str(root / "sdk")],
                env={**os.environ, "TDVP_FEED_STAGING_ROOT": str(root / "stage"),
                     "FIXTURE_SOURCE": str(source.parent), "EXPECTED_LICENSE": str(source.parent / "LICENSE")},
                text=True, capture_output=True,
            )
            self.assertEqual(result.returncode, 73, result.stdout + result.stderr)
            self.assertIn("native-source-layout-verified", result.stdout)
            self.assertEqual((root / "stage/.tdvp-native/icu/LICENSE").read_bytes(), license_bytes)
            self.assertFalse((root / "stage/.tdvp-node22-icu-inputs-v1").exists())


if __name__ == "__main__":
    unittest.main()
