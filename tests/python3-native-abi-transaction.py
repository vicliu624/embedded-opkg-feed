"""Use the paired target opkg to enforce the native CPython minor ABI range."""
import importlib.util
import os
from pathlib import Path
import subprocess
import unittest

spec = importlib.util.spec_from_file_location("composition_fixture", Path(__file__).with_name("image-backed-compose.py"))
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)


@unittest.skipUnless(os.environ.get("TDVP_TEST_OPKG"), "requires the paired target opkg runner")
class NativeAbiTransaction(unittest.TestCase):
    def test_install_rejects_incompatible_python_and_accepts_current(self):
        for version, accepted in (("3.13.3-2+tdvpimg.test", True), ("3.13.3-1", False),
                                  ("3.14.0", False), ("3.14~rc1", False), ("3.15.0", False)):
            with self.subTest(version=version):
                f = fixture.Compose()
                f.setUp()
                try:
                    # A real package transaction, not only compare-versions:
                    # require both bounds on the same installed Python provider.
                    f.make_package("native-extension", "usr/share/test/native-extension", b"native-abi-marker",
                                   "python3 (>= 3.13.3-2), python3 (<< 3.14~)")
                    subprocess.run(["bash", str(Path(__file__).resolve().parents[1] / "scripts/make-index.sh"),
                                    str(f.source)], check=True, capture_output=True)
                    database = f.image / "var/lib/opkg"
                    (database / "info").mkdir(parents=True)
                    (database / "lists").mkdir()
                    (database / "lists/test").write_bytes((f.source / "Packages").read_bytes())
                    status = database / "status"
                    original = ("Package: python3\nVersion: " + version + "\nArchitecture: riscv64\n"
                                "Status: install hold installed\n\n")
                    status.write_text(original)
                    config = f.work / "opkg.conf"
                    config.write_text("dest root /\noption lists_dir /var/lib/opkg/lists\n"
                                      "option info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n"
                                      "arch riscv64 10\nsrc test " + f.source.as_uri() + "\n")
                    result = subprocess.run([os.environ["TDVP_TEST_OPKG"], "-f", str(config), "-o", str(f.image),
                                             "install", "native-extension"], capture_output=True, text=True)
                    marker = f.image / "usr/share/test/native-extension"
                    if accepted:
                        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertEqual(marker.read_bytes(), b"native-abi-marker")
                    else:
                        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                        self.assertFalse(marker.exists())
                        self.assertEqual(status.read_text(), original)
                finally:
                    f.doCleanups()


if __name__ == "__main__":
    unittest.main(verbosity=2)
