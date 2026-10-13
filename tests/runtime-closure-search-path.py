#!/usr/bin/env python3
"""Exercise the production closure guard with real native ELF fixtures."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class RuntimeSearchPaths(unittest.TestCase):
    def test_real_elf_search_paths(self):
        for search_path, accepted in ((None, True), ("", True),
                                      ("$ORIGIN/lib", False), ("/tmp/sdk/usr/lib", False),
                                      (":", False)):
            with self.subTest(search_path=search_path), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                payload = root / "data/usr/bin"
                payload.mkdir(parents=True)
                control = root / "control"
                control.mkdir()
                base = root / "base"
                (base / "lib").mkdir(parents=True)
                (base / "usr/lib").mkdir(parents=True)
                feed = root / "feed"
                feed.mkdir()
                source = root / "fixture.c"
                source.write_text("int main(void) { return 0; }\n")
                # Isolate search-path validation from host libc dependencies;
                # the generated dynamic ELF is inspected, never executed.
                command = ["gcc", "-shared", "-nostdlib", str(source), "-o", str(payload / "fixture")]
                if search_path is not None:
                    command.append("-Wl,--enable-new-dtags,-rpath," + search_path)
                subprocess.run(command, check=True)
                (control / "control").write_text("Package: fixture\nVersion: 1\nArchitecture: riscv64\n")
                (feed / "Packages").write_text("Package: fixture\n\n")
                for name in ("control", "data"):
                    subprocess.run(["tar", "-czf", str(root / (name + ".tar.gz")),
                                    "-C", str(root / name), "."], check=True)
                subprocess.run(["ar", "rc", str(feed / "fixture.ipk"),
                                str(root / "control.tar.gz"), str(root / "data.tar.gz")], check=True)
                result = subprocess.run(["bash", str(REPO / "scripts/verify-runtime-closure.sh"),
                                         "--platform", "tdvp-k230-r1", "--base-root", str(base), str(feed)],
                                        capture_output=True, text=True)
                self.assertEqual(result.returncode, 0 if accepted else 79,
                                 result.stdout + result.stderr)


if __name__ == "__main__":
    for tool in ("gcc", "ar", "tar", "readelf", "bash"):
        if not shutil.which(tool):
            raise SystemExit("required test tool missing: " + tool)
    unittest.main(verbosity=2)
