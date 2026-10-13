#!/usr/bin/env python3
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from compose_image_backed_feed import compose_image_backed_feed, archive_directory, control_fields
from image_backed_payload import file_record


class Compose(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.source, self.image = self.work / "source", self.work / "image"
        self.source.mkdir()
        library = self.image / "usr/lib/libbase.so.1"
        library.parent.mkdir(parents=True)
        library.write_bytes(b"base-library")
        library.chmod(0o644)
        manifest = {"files": {"/usr/lib/libbase.so.1": file_record(library)},
                    "owners": {"/usr/lib/libbase.so.1": "tdvp-image-base-lib"},
                    "installed_packages": {"tdvp-image-base-lib": {"Package": "tdvp-image-base-lib", "Version": "1+locked"}}}
        content = json.dumps(manifest).encode()
        path = self.image / "usr/share/tdvp/opkg/image-base.json"
        path.parent.mkdir(parents=True)
        path.write_bytes(content)
        self.digest = hashlib.sha256(content).hexdigest()
        self.make_package("libbase", "usr/lib/libbase.so.1", b"base-library")
        self.make_package("consumer", "usr/bin/consumer", b"consumer", "libbase (= 1-1)")
        self.make_package("independent", "usr/bin/independent", b"independent")

    def make_package(self, name, path, data, depends="", script=None):
        staging = self.work / ("staging-" + name)
        staging.mkdir()
        control, payload = staging / "control", staging / "payload"
        control.mkdir()
        (payload / path).parent.mkdir(parents=True)
        (payload / path).write_bytes(data)
        (payload / path).chmod(0o644)
        (control / "control").write_text("Package: " + name + "\nVersion: 1-1\nArchitecture: riscv64\n"
                                         + ("Depends: " + depends + "\n" if depends else "") + "Description: test\n")
        if script:
            (control / "postinst").write_text(script)
        (staging / "control.tar.gz").write_bytes(archive_directory(control))
        (staging / "data.tar.gz").write_bytes(archive_directory(payload))
        (staging / "debian-binary").write_bytes(b"2.0\n")
        subprocess.run(["ar", "rD", str(self.source / (name + "_1-1_riscv64.ipk")),
                        "debian-binary", "control.tar.gz", "data.tar.gz"], cwd=staging, check=True, capture_output=True)

    def fields(self, ipk):
        raw = subprocess.check_output(["ar", "p", str(ipk), "control.tar.gz"])
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive:
            return control_fields(archive.extractfile("./control").read().decode().replace(
                "X-TDVP-Image-Manifest-SHA256:", "Inspected-Image-Manifest-SHA256:"))

    def test_reference_consumer_and_unchanged_payload(self):
        output = self.work / "candidate"
        report = compose_image_backed_feed(self.source, self.image, self.digest, output)
        reference = next(output.glob("libbase_*.ipk"))
        fields = self.fields(reference)
        self.assertEqual(fields["Depends"], "tdvp-image-base-lib (= 1+locked)")
        data = subprocess.check_output(["ar", "p", str(reference), "data.tar.gz"])
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
            self.assertFalse([member for member in archive if not member.isdir()])
        consumer = next(output.glob("consumer_*.ipk"))
        self.assertEqual(self.fields(consumer)["Depends"], "libbase (= " + fields["Version"] + ")")
        self.assertEqual(subprocess.check_output(["ar", "p", str(consumer), "data.tar.gz"]),
                         subprocess.check_output(["ar", "p", str(self.source / "consumer_1-1_riscv64.ipk"), "data.tar.gz"]))
        self.assertTrue(report["packages"]["independent"]["reused"])
        self.assertEqual((output / "independent_1-1_riscv64.ipk").read_bytes(),
                         (self.source / "independent_1-1_riscv64.ipk").read_bytes())

    def test_determinism_and_incremental_identity(self):
        first, second = self.work / "first", self.work / "second"
        a = compose_image_backed_feed(self.source, self.image, self.digest, first)
        self.make_package("unrelated", "usr/bin/unrelated", b"unrelated")
        b = compose_image_backed_feed(self.source, self.image, self.digest, second)
        for name in a["packages"]:
            self.assertEqual(a["packages"][name]["version"], b["packages"][name]["version"])
        for path in first.glob("*.ipk"):
            self.assertEqual(path.read_bytes(), (second / path.name).read_bytes())

    def test_mismatch_leaves_no_candidate(self):
        (self.image / "usr/lib/libbase.so.1").write_bytes(b"drift")
        with self.assertRaisesRegex(ValueError, "locked inventory"):
            compose_image_backed_feed(self.source, self.image, self.digest, self.work / "candidate")
        self.assertFalse((self.work / "candidate").exists())

    def test_arbitrary_reference_hooks_are_rejected(self):
        self.make_package("hooked", "usr/lib/libbase.so.1", b"base-library", script="#!/bin/sh\nexit 0\n")
        with self.assertRaisesRegex(ValueError, "control member"):
            compose_image_backed_feed(self.source, self.image, self.digest, self.work / "candidate")
        self.assertFalse((self.work / "candidate").exists())

    def test_unsupported_version_range_is_rejected(self):
        # Ordinary package ranges are supported. Firmware owner references
        # must still name one exact immutable version, never a range.
        self.make_package("range", "usr/bin/range", b"range", "tdvp-image-base-lib (>= 1+locked)")
        with self.assertRaisesRegex(ValueError, "locked version"):
            compose_image_backed_feed(self.source, self.image, self.digest, self.work / "candidate")

    def test_image_alternatives_are_version_bound(self):
        self.make_package("alternative", "usr/bin/alternative", b"alternative", "libbase (= 1-1) | tdvp-image-base-lib")
        output = self.work / "candidate"
        compose_image_backed_feed(self.source, self.image, self.digest, output)
        fields = self.fields(next(output.glob("alternative_*.ipk")))
        self.assertIn("| tdvp-image-base-lib (= 1+locked)", fields["Depends"])
        report = json.loads((output / "image-backed-report.json").read_text())
        self.assertEqual(fields["X-TDVP-Image-Plan-SHA256"], hashlib.sha256(
            json.dumps(report["packages"]["alternative"]["plan"], sort_keys=True).encode()).hexdigest())

    def test_dependency_source_change_updates_consumer_identity(self):
        before = compose_image_backed_feed(self.source, self.image, self.digest, self.work / "first")
        staging = self.work / "staging-libbase"
        control = staging / "control/control"
        control.write_text(control.read_text().replace("Description: test", "Description: changed"))
        (staging / "control.tar.gz").write_bytes(archive_directory(staging / "control"))
        subprocess.run(["ar", "rD", str(self.source / "libbase_1-1_riscv64.ipk"), "control.tar.gz"],
                       cwd=staging, check=True, capture_output=True)
        after = compose_image_backed_feed(self.source, self.image, self.digest, self.work / "second")
        for name in ("libbase", "consumer"):
            self.assertNotEqual(before["packages"][name]["version"], after["packages"][name]["version"])
        self.assertEqual(before["packages"]["independent"], after["packages"]["independent"])

    def test_mixed_payload_preserves_private_directory_modes(self):
        self.make_package("mixed", "usr/lib/libbase.so.1", b"base-library")
        staging = self.work / "staging-mixed"
        private = staging / "payload/home/private"
        private.mkdir(parents=True)
        private.chmod(0o700)
        (private / "data").write_bytes(b"private")
        (private / "data").chmod(0o600)
        (staging / "data.tar.gz").write_bytes(archive_directory(staging / "payload"))
        subprocess.run(["ar", "rD", str(self.source / "mixed_1-1_riscv64.ipk"), "data.tar.gz"],
                       cwd=staging, check=True, capture_output=True)
        output = self.work / "candidate"
        compose_image_backed_feed(self.source, self.image, self.digest, output)
        raw = subprocess.check_output(["ar", "p", str(next(output.glob("mixed_*.ipk"))), "data.tar.gz"])
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as archive:
            self.assertEqual(archive.getmember("./home/private").mode, 0o700)
            self.assertEqual(archive.getmember("./home/private/data").mode, 0o600)
            self.assertNotIn("./usr/lib/libbase.so.1", archive.getnames())

    @unittest.skipUnless(os.environ.get("TDVP_TEST_OPKG"), "native opkg transaction check requires TDVP_TEST_OPKG")
    def test_real_install_remove_keeps_base_file_and_owner(self):
        self.make_package("alternative", "usr/bin/alternative", b"alternative", "libbase (= 1-1) | tdvp-image-base-lib")
        output = self.work / "candidate"
        compose_image_backed_feed(self.source, self.image, self.digest, output)
        database = self.image / "var/lib/opkg"
        (database / "info").mkdir(parents=True)
        (database / "lists").mkdir()
        (database / "lists/test").write_bytes((output / "Packages").read_bytes())
        (database / "status").write_text("Package: tdvp-image-base-lib\nVersion: 1+locked\nArchitecture: riscv64\n"
                                          "Status: install hold installed\nEssential: yes\n\n")
        owner_list = database / "info/tdvp-image-base-lib.list"
        owner_list.write_text("/usr/lib/libbase.so.1\n")
        before = owner_list.read_bytes()
        config = self.work / "opkg.conf"
        config.write_text("dest root /\noption lists_dir /var/lib/opkg/lists\n"
                          "option info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n"
                          "arch riscv64 10\nsrc test " + output.as_uri() + "\n")
        command = [os.environ["TDVP_TEST_OPKG"], "-f", str(config), "-o", str(self.image)]
        for action in (["install", "consumer"], ["remove", "consumer"], ["remove", "libbase"]):
            result = subprocess.run(command + action, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual((self.image / "usr/lib/libbase.so.1").read_bytes(), b"base-library")
            self.assertEqual(owner_list.read_bytes(), before)
            self.assertIn("Status: install hold installed", (database / "status").read_text())
        status = database / "status"
        status.write_text(status.read_text().replace("Version: 1+locked", "Version: 0+wrong"))
        result = subprocess.run(command + ["install", "alternative"], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse((self.image / "usr/bin/alternative").exists())
        self.assertEqual(owner_list.read_bytes(), before)


if __name__ == "__main__":
    unittest.main(verbosity=2)
