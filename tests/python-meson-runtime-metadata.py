"""Check native module metadata identity, requirements, licenses and boundaries."""
import importlib.util
from importlib.metadata import Distribution
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("meson_metadata", Path(__file__).resolve().parents[1] / "support/python-meson-runtime-metadata.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class MetadataProjection(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.source = self.work / "source"
        self.source.mkdir()
        self.payload = self.work / "payload"
        self.site = self.payload / "usr/lib/python3.13/site-packages"
        (self.site / "scipy").mkdir(parents=True)
        self.metadata = b'Metadata-Version: 2.1\nName: scipy\nVersion: 1.15.3\nRequires-Python: >=3.10\nRequires-Dist: numpy<2.5,>=1.23.5\n\nUpstream description\n'
        (self.source / "PKG-INFO").write_bytes(self.metadata)
        (self.source / "LICENSE.txt").write_text("license fixture")

    def project(self):
        module.project_metadata(self.source, self.payload, "scipy", "1.15.3")
        return self.site / "scipy-1.15.3.dist-info"

    def test_metadata_and_runtime_bounds_are_preserved(self):
        destination = self.project()
        self.assertEqual((destination / "METADATA").read_bytes(), self.metadata)
        distribution = Distribution.at(destination)
        self.assertEqual(distribution.version, "1.15.3")
        self.assertEqual(distribution.requires, ["numpy<2.5,>=1.23.5"])
        self.assertIn("cp313-cp313-linux_riscv64", (destination / "WHEEL").read_text())
        self.assertEqual((destination / "licenses/LICENSE.txt").read_text(), "license fixture")

    def test_wrong_version_rejected_before_output(self):
        with self.assertRaises(ValueError):
            module.project_metadata(self.source, self.payload, "scipy", "2.0.0")
        self.assertFalse(list(self.site.glob("*.dist-info")))

    def test_missing_license_rejected_before_output(self):
        (self.source / "LICENSE.txt").unlink()
        with self.assertRaises(ValueError):
            self.project()
        self.assertFalse(list(self.site.glob("*.dist-info")))

    def test_license_path_escape_rejected(self):
        (self.source / "PKG-INFO").write_bytes(self.metadata.replace(b"\n\n", b"\nLicense-File: ../secret\n\n"))
        with self.assertRaises(ValueError):
            self.project()
        self.assertFalse(list(self.site.glob("*.dist-info")))

    def test_overwrite_rejected(self):
        destination = self.project()
        (destination / "METADATA").write_text("tampered")
        with self.assertRaises(ValueError):
            self.project()

    def test_repeated_identical_projection_is_idempotent(self):
        destination = self.project()
        before = (destination / "METADATA").read_bytes()
        self.project()
        self.assertEqual((destination / "METADATA").read_bytes(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
