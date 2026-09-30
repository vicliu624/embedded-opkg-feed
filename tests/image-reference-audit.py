#!/usr/bin/env python3
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from compose_image_backed_feed import compose_image_backed_feed, extract_archive
from materialize_image_references import materialize_references

spec = importlib.util.spec_from_file_location("compose_fixtures", Path(__file__).with_name("image-backed-compose.py"))
fixtures = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixtures)


class ReferenceAudit(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.Compose()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.work = self.fixture.work
        self.output = self.work / "candidate"
        compose_image_backed_feed(self.fixture.source, self.fixture.image, self.fixture.digest, self.output)
        self.ipk = next(self.output.glob("libbase_*.ipk"))
        self.original_ipk = self.ipk.read_bytes()
        self.payload, self.control_dir = self.work / "audit", self.work / "control"
        extract_archive(subprocess.check_output(["ar", "p", str(self.ipk), "data.tar.gz"]), self.payload)
        extract_archive(subprocess.check_output(["ar", "p", str(self.ipk), "control.tar.gz"]), self.control_dir)
        self.control = self.control_dir / "control"
        self.report_path = self.output / "image-backed-report.json"
        self.report = json.loads(self.report_path.read_text())

    def verify(self, digest=None):
        return materialize_references(self.control, self.payload, self.fixture.image,
                                       self.report_path, self.fixture.digest if digest is None else digest)

    def save_report(self, rebind=False):
        self.report_path.write_text(json.dumps(self.report))
        if rebind:
            digest = hashlib.sha256(json.dumps(self.report["packages"]["libbase"]["plan"], sort_keys=True).encode()).hexdigest()
            lines = self.control.read_text().splitlines()
            self.control.write_text("\n".join("X-TDVP-Image-Plan-SHA256: " + digest if line.startswith("X-TDVP-Image-Plan-SHA256:") else line for line in lines) + "\n")

    def test_verified_references_materialize_only_in_audit_root(self):
        self.assertEqual(self.verify(), 1)
        self.assertEqual((self.payload / "usr/lib/libbase.so.1").read_bytes(), b"base-library")
        self.assertEqual(self.ipk.read_bytes(), self.original_ipk)
        self.assertEqual((self.fixture.image / "usr/lib/libbase.so.1").read_bytes(), b"base-library")

    def test_report_tamper_fails_before_copy(self):
        self.report["packages"]["libbase"]["plan"]["image_files"]["/usr/lib/libbase.so.1"]["record"]["sha256"] = "0" * 64
        self.save_report()
        with self.assertRaisesRegex(ValueError, "plan hash"):
            self.verify()
        self.assertFalse((self.payload / "usr/lib/libbase.so.1").exists())

    def test_rebound_forged_owner_is_rejected(self):
        self.report["packages"]["libbase"]["plan"]["image_files"]["/usr/lib/libbase.so.1"]["owner"] = "tdvp-image-wrong"
        self.save_report(rebind=True)
        with self.assertRaisesRegex(ValueError, "owner differs"):
            self.verify()

    def test_exact_owner_must_be_required_not_optional(self):
        self.control.write_text(self.control.read_text().replace("tdvp-image-base-lib (= 1+locked)",
                                                               "tdvp-image-base-lib (= 1+locked) | other"))
        with self.assertRaisesRegex(ValueError, "required exact owner"):
            self.verify()

    def test_wrong_owner_version_is_rejected(self):
        self.control.write_text(self.control.read_text().replace("tdvp-image-base-lib (= 1+locked)",
                                                               "tdvp-image-base-lib (= 0+wrong)"))
        with self.assertRaisesRegex(ValueError, "required exact owner"):
            self.verify()

    def test_image_lock_is_required(self):
        for digest in ("", "0" * 64):
            with self.subTest(digest=digest), self.assertRaisesRegex(ValueError, "locked image"):
                self.verify(digest)

    def test_duplicate_image_payload_is_rejected(self):
        duplicate = self.payload / "usr/lib/libbase.so.1"
        duplicate.parent.mkdir(parents=True)
        duplicate.write_bytes(b"base-library")
        with self.assertRaisesRegex(ValueError, "remaining payload"):
            self.verify()

    def test_undeclared_payload_is_rejected(self):
        (self.payload / "smuggled").write_bytes(b"unexpected")
        with self.assertRaisesRegex(ValueError, "remaining payload"):
            self.verify()

    def test_traversal_reference_is_rejected(self):
        files = self.report["packages"]["libbase"]["plan"]["image_files"]
        files["/../escape"] = files.pop("/usr/lib/libbase.so.1")
        self.save_report(rebind=True)
        with self.assertRaisesRegex(ValueError, "invalid reference path"):
            self.verify()

    def test_image_drift_is_rejected(self):
        (self.fixture.image / "usr/lib/libbase.so.1").write_bytes(b"changed")
        with self.assertRaisesRegex(ValueError, "locked image"):
            self.verify()


if __name__ == "__main__":
    unittest.main(verbosity=2)
