#!/usr/bin/env python3
"""Filesystem-backed tests for exact image-owner payload planning."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("planner", Path(__file__).resolve().parents[1] / "scripts/image_backed_payload.py")
planner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(planner)


class ImagePayload(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.work = Path(self.temporary.name)
        self.image, self.payload = self.work / "image", self.work / "payload"
        for root in (self.image, self.payload):
            (root / "usr/lib").mkdir(parents=True)
            (root / "usr/lib/libone.so.1").write_bytes(b"one")
            (root / "usr/lib/libone.so.1").chmod(0o644)
            (root / "usr/lib/libone.so").symlink_to("libone.so.1")
        self.manifest = {"files": {}, "owners": {}, "installed_packages": {}}
        for path in ("/usr/lib/libone.so.1", "/usr/lib/libone.so"):
            self.manifest["files"][path] = planner.file_record(self.image / path.lstrip("/"))
            self.manifest["owners"][path] = "tdvp-image-one"
        self.manifest["installed_packages"]["tdvp-image-one"] = {"Package": "tdvp-image-one", "Version": "1+abc"}
        self.manifest_path = self.image / "usr/share/tdvp/opkg/image-base.json"
        self.manifest_path.parent.mkdir(parents=True)

    def plan(self):
        content = json.dumps(self.manifest).encode()
        self.manifest_path.write_bytes(content)
        return planner.plan_image_payload(self.payload, self.image, hashlib.sha256(content).hexdigest())

    def test_exact_and_new_payloads_are_separated_without_writes(self):
        (self.payload / "usr/lib/libnew.so.1").write_bytes(b"new")
        before = (self.payload / "usr/lib/libone.so.1").read_bytes()
        result = self.plan()
        self.assertEqual(len(result["image_files"]), 2)
        self.assertEqual(list(result["new_files"]), ["/usr/lib/libnew.so.1"])
        self.assertEqual(result["depends"], ["tdvp-image-one (= 1+abc)"])
        self.assertEqual((self.payload / "usr/lib/libone.so.1").read_bytes(), before)

    def test_multiple_owners_require_all_exact_versions(self):
        self.manifest["owners"]["/usr/lib/libone.so"] = "tdvp-image-two"
        self.manifest["installed_packages"]["tdvp-image-two"] = {"Package": "tdvp-image-two", "Version": "2+def"}
        self.assertEqual(self.plan()["depends"], ["tdvp-image-one (= 1+abc)", "tdvp-image-two (= 2+def)"])

    def test_payload_bytes_permissions_and_symlinks_are_checked(self):
        for change in ("bytes", "mode", "link"):
            with self.subTest(change=change):
                file = self.payload / "usr/lib/libone.so.1"
                link = self.payload / "usr/lib/libone.so"
                file.write_bytes(b"different" if change == "bytes" else b"one")
                file.chmod(0o755 if change == "mode" else 0o644)
                link.unlink()
                link.symlink_to("wrong" if change == "link" else "libone.so.1")
                with self.assertRaisesRegex(ValueError, "payload differs"):
                    self.plan()

    def test_image_drift_is_rejected(self):
        (self.image / "usr/lib/libone.so.1").write_bytes(b"drift")
        with self.assertRaisesRegex(ValueError, "locked inventory"):
            self.plan()

    def test_missing_and_invalid_owner_are_rejected(self):
        del self.manifest["owners"]["/usr/lib/libone.so"]
        with self.assertRaisesRegex(ValueError, "valid exact owner"):
            self.plan()

    def test_unrecorded_image_overlap_is_rejected(self):
        del self.manifest["files"]["/usr/lib/libone.so"]
        with self.assertRaisesRegex(ValueError, "lacks a file record"):
            self.plan()

    def test_manifest_lock_is_required(self):
        self.plan()
        with self.assertRaisesRegex(ValueError, "digest differs"):
            planner.plan_image_payload(self.payload, self.image, "0" * 64)

    def test_usrmerge_parent_alias_is_canonicalized(self):
        (self.image / "lib").symlink_to("usr/lib")
        (self.payload / "lib").mkdir()
        (self.payload / "lib/libone.so.1").write_bytes(b"one")
        (self.payload / "lib/libone.so.1").chmod(0o644)
        self.assertEqual(self.plan()["image_files"]["/lib/libone.so.1"]["canonical_path"], "/usr/lib/libone.so.1")

    def test_parent_symlink_escape_is_rejected(self):
        (self.image / "escape").symlink_to(self.work)
        (self.payload / "escape").mkdir()
        (self.payload / "escape/file").write_bytes(b"escape")
        with self.assertRaisesRegex(ValueError, "parent escapes"):
            self.plan()

    def test_conflicting_usrmerge_aliases_are_rejected(self):
        (self.image / "lib").symlink_to("usr/lib")
        (self.payload / "lib").mkdir()
        (self.payload / "lib/new").write_bytes(b"one")
        (self.payload / "usr/lib/new").write_bytes(b"two")
        with self.assertRaisesRegex(ValueError, "aliases disagree"):
            self.plan()

    def test_version_control_injection_is_rejected(self):
        self.manifest["installed_packages"]["tdvp-image-one"]["Version"] = "1\nDepends: injected"
        with self.assertRaisesRegex(ValueError, "valid exact owner"):
            self.plan()

    def test_image_permission_drift_is_rejected(self):
        (self.image / "usr/lib/libone.so.1").chmod(0o755)
        with self.assertRaisesRegex(ValueError, "locked inventory"):
            self.plan()


if __name__ == "__main__":
    unittest.main(verbosity=2)
