#!/usr/bin/env python3
"""Published-input workflow contract and rootfs extraction regression tests."""
import gzip
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("extractor", ROOT / "scripts/extract-published-rootfs.py")
extractor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extractor)


class PublishedSdkContract(unittest.TestCase):
    def test_workflows_consume_release_without_firmware_build(self):
        for name in ("build-audacious-candidate.yml", "build-r10-batch-candidate.yml"):
            content = (ROOT / ".github/workflows" / name).read_text()
            self.assertIn("uses: ./.github/actions/published-sdk", content)
            for forbidden in ("build-k230-sdk", "prepare-k230-sdk-worktree", ".stamp_", "working-directory: firmware", "repository: vicliu624/t-display-k230-vision-platform"):
                self.assertNotIn(forbidden, content)

    def test_release_hashes_are_verified_before_sdk_execution(self):
        content = (ROOT / "scripts/prepare-published-sdk.sh").read_text()
        self.assertLess(content.index('fetch "$SDK_ARCHIVE"'), content.index('tar -xzf'))
        self.assertLess(content.index('cmp "$cache/tdvp-sdk-manifest.json"'), content.index('verify-sdk.py'))
        self.assertIn('fetch "$SDK_IMAGE_ARCHIVE" "$SDK_IMAGE_SHA256"', content)

    def test_legacy_zip_never_executes_cross_compiled_probes(self):
        builder = (ROOT / "support/published-sdk-build.sh").read_text()
        zip_builder = builder.split("    zip)\n", 1)[1].split("    unzip)\n", 1)[0]
        self.assertIn("-DUIDGID_NOT_16BIT", zip_builder)
        self.assertIn("-DLARGE_FILE_SUPPORT", zip_builder)
        self.assertIn("OCRCU8='crc32_.o'", zip_builder)
        self.assertIn("make -f unix/Makefile zips", zip_builder)
        self.assertNotIn("generic", zip_builder)

    def test_source_builds_use_the_sdk_stable_optimization_path(self):
        builder = (ROOT / "support/published-sdk-build.sh").read_text()
        self.assertIn('CFLAGS="$CFLAGS -fPIC -fno-shrink-wrap -O1"', builder)

    @unittest.skipUnless(shutil.which("mke2fs") and shutil.which("debugfs"), "e2fsprogs required")
    def test_extract_and_validate_named_root_partition(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "source"
            (source / "usr/lib").mkdir(parents=True)
            library = source / "usr/lib/fixture"
            library.write_bytes(b"published image bytes\n")
            library.chmod(0o644)
            (source / "lib").symlink_to("usr/lib")
            fs = root / "rootfs.ext4"
            subprocess.run(["mke2fs", "-q", "-t", "ext4", "-d", str(source), str(fs), "8192"], check=True, capture_output=True)
            header = bytearray(512)
            header[:8] = b"EFI PART"
            struct.pack_into("<QII", header, 72, 2, 1, 128)
            entry = bytearray(128)
            first = 2048
            struct.pack_into("<QQ", entry, 32, first, first + fs.stat().st_size // 512 - 1)
            name = "rootfs".encode("utf-16-le")
            entry[56:56 + len(name)] = name
            archive = root / "image.gz"
            with gzip.open(archive, "wb") as out:
                out.write(bytes(512) + header + entry)
                out.write(bytes(first * 512 - 1024 - 128))
                with fs.open("rb") as stream:
                    shutil.copyfileobj(stream, out)
            inventory = {"schema": 1, "ownership_mode": "buildroot", "files": {
                "/usr/lib/fixture": {"type": "file", "mode": 0o644, "sha256": hashlib.sha256(library.read_bytes()).hexdigest()},
                "/lib": {"type": "symlink", "mode": 0o777, "target": "usr/lib"},
            }}
            manifest = root / "inventory.json"
            manifest.write_text(json.dumps(inventory))
            destination = root / "target"
            extractor.extract(archive, manifest, destination)
            self.assertEqual((destination / "usr/lib/fixture").read_bytes(), library.read_bytes())
            self.assertEqual((destination / "usr/lib/fixture").stat().st_mode & 0o777, 0o644)
            with self.assertRaisesRegex(ValueError, "destination exists"):
                extractor.extract(archive, manifest, destination)
            inventory["files"]["/usr/lib/fixture"]["sha256"] = "0" * 64
            manifest.write_text(json.dumps(inventory))
            with self.assertRaisesRegex(ValueError, "image file differs"):
                extractor.extract(archive, manifest, root / "bad-target")


if __name__ == "__main__":
    unittest.main()
