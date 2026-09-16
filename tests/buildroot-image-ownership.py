#!/usr/bin/env python3
"""Exercise the catalogue's actual embedded Buildroot ownership parser."""
import csv
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


CATALOGUE = Path(__file__).resolve().parents[1] / "scripts/build-runtime-catalog.sh"
SOURCE = CATALOGUE.read_text(encoding="utf-8")
PARSER = SOURCE.split('python3 - "$target_root" "$build_dir" <<\'PY\'\n', 1)[1].split("\nPY\n", 1)[0]


class BuildrootOwnershipTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.target = self.root / "target"
        self.build = self.root / "build"
        (self.target / "usr/lib").mkdir(parents=True)
        self.build.mkdir()
        (self.target / "usr/lib/libfixture.so.1").touch()

    def records(self, directory, rows):
        destination = self.build / directory / ".files-list.txt"
        destination.parent.mkdir(parents=True)
        with destination.open("w", newline="", encoding="utf-8") as stream:
            csv.writer(stream).writerows(rows)

    def parse(self):
        result = subprocess.run(
            [sys.executable, "-", str(self.target), str(self.build)],
            input=PARSER, text=True, capture_output=True, check=True,
        )
        # Bash consumes these records with IFS=$'\t' read -r path package.
        return [line.split("\t") for line in result.stdout.splitlines()]

    def test_buildroot_record_produces_tab_separated_owner(self):
        self.records("fixture-1.0", [("fixture_lib", "./usr/lib/libfixture.so.1")])
        self.assertEqual(self.parse(), [["/usr/lib/libfixture.so.1", "tdvp-image-fixture-lib"]])

    def test_usrmerge_and_duplicate_claims(self):
        (self.target / "lib").symlink_to("usr/lib", target_is_directory=True)
        self.records("fixture-1.0", [
            ("fixture", "lib/libfixture.so.1"),
            ("fixture", "usr/lib/libfixture.so.1"),
        ])
        self.assertEqual(self.parse(), [["/usr/lib/libfixture.so.1", "tdvp-image-fixture"]])

    def test_catalogue_shell_recovers_ownership_without_image_manifest(self):
        self.records("fixture-1.0", [("fixture", "./usr/lib/libfixture.so.1")])
        # Execute the whole production fallback, including Bash's TSV reader
        # and the exit-79 guard that failed in the candidate workflow.
        ownership_block = "image_manifest=${" + SOURCE.split("image_manifest=${", 1)[1].split(
            '\nfor soname in "${!soname_file[@]}";', 1
        )[0]
        harness = (
            'set -Eeuo pipefail\n'
            'unset TDVP_IMAGE_PROVIDER_MANIFEST\n'
            'target_root=$1\n' + ownership_block + '\n'
            'printf "%s\\n" "${image_path_owner[/usr/lib/libfixture.so.1]}"\n'
        )
        result = subprocess.run(
            ["bash", "-c", harness, "ownership-test", str(self.target)],
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "tdvp-image-fixture\n")
        self.assertIn("recovered transitional image ownership", result.stderr)

    def test_ambiguous_missing_and_invalid_records_are_rejected(self):
        self.records("fixture-1.0", [
            ("one", "usr/lib/libfixture.so.1"),
            ("two", "usr/lib/libfixture.so.1"),
            ("one", "usr/lib/missing.so.1"),
            ("bad package", "usr/lib/libfixture.so.1"),
            ("one", "../target/usr/lib/libfixture.so.1"),
            ("one", "/usr/lib/libfixture.so.1"),
        ])
        self.assertEqual(self.parse(), [])


if __name__ == "__main__":
    unittest.main()
