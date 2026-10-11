"""Exercise actual native IPK constraints with paired target opkg (dry run).

The providers are metadata-only installed fixtures. This tests dependency
resolution, not payload installation or application functionality.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--feed", type=Path, required=True)
parser.add_argument("--target-root", type=Path, required=True)
args = parser.parse_args()
feed, target = args.feed.resolve(strict=True), args.target_root.resolve(strict=True)
repo = Path(__file__).resolve().parents[1]
records = []
for block in (feed / "Packages").read_text().split("\n\n"):
    record = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line)
    if "Package" in record:
        records.append(record)
native = {"python3-" + name for name in
          ("numpy", "scipy", "pillow", "opencv", "onnx", "onnxruntime", "cffi", "protobuf", "pyyaml", "tflite-runtime")}
assert native <= {record["Package"] for record in records}, "missing required native package"
environment = dict(os.environ, TDVP_TEST_TARGET_ROOT=str(target))
count = 0
with tempfile.TemporaryDirectory(prefix="tdvp-final-native-abi-") as directory:
    work = Path(directory)
    for tested in (record for record in records if record["Package"] in native):
        assert "python3 (<< 3.14~)" in tested["Depends"], tested["Package"]
        for version, accepted in (("3.13.3-2+tdvp.test", True), ("3.13.3-1", False),
                                  ("3.14.0", False), ("3.14~rc1", False), ("3.15.0", False)):
            root = work / (tested["Package"] + "-" + version) / "root"
            database = root / "var/lib/opkg"
            shutil.copytree(target / "var/lib/opkg", database, symlinks=True)
            original = (database / "status").read_text()
            for record in records:
                if record["Package"] in (tested["Package"], "python3"):
                    continue
                original += ("Package: " + record["Package"] + "\nVersion: " + record["Version"] +
                             "\nArchitecture: riscv64\nStatus: install hold installed\n\n")
                (database / "info" / (record["Package"] + ".list")).write_text("")
            original += ("Package: python3\nVersion: " + version +
                         "\nArchitecture: riscv64\nStatus: install hold installed\n\n")
            (database / "info/python3.list").write_text("")
            (database / "status").write_text(original)
            configuration = root.parent / "opkg.conf"
            configuration.write_text("dest root /\noption lists_dir /var/lib/opkg/lists\n"
                                     "option info_dir /var/lib/opkg/info\n"
                                     "option status_file /var/lib/opkg/status\narch riscv64 10\n")
            filename = tested["Filename"]
            assert Path(filename).name == filename and filename.endswith(".ipk")
            result = subprocess.run(["bash", str(repo / "tests/opkg-target-runner.sh"), "-f", str(configuration),
                                     "-o", str(root), "--noaction", "install", str(feed / filename)],
                                    env=environment, capture_output=True, text=True)
            assert (result.returncode == 0) == accepted, (tested["Package"], version, result.stdout, result.stderr)
            assert (database / "status").read_text() == original
            count += 1
print("Actual native IPK ABI dependency preflight: PASS", count, "scenarios")
