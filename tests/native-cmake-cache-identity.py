"""Check native cache reuse binds flags, helpers and host dependency identity."""
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tdvp-native-cache-policy-") as directory:
    root = Path(directory)
    for name in ("scripts", "support", "packages/fixture", "dependency", "cache/bin"):
        (root / name).mkdir(parents=True)
    for name in ("scripts/native-cmake-cache-key.py", "support/native-cmake-input.sh", "support/source-archive-library.sh"):
        shutil.copy2(source / name, root / name)
    package = root / "packages/fixture"
    (package / "source.lock").write_text("UPSTREAM_VERSION='1'\n")
    (package / "package.env").write_text("PACKAGE='fixture'\n")
    marker = root / "dependency/.tdvp-source-key"
    marker.write_text("dependency-one\n")
    command = [sys.executable, str(root / "scripts/native-cmake-cache-key.py"), str(package),
               str(root / "cache"), "bin/generator", "-DFIXTURE=ON", "-DCMAKE_PREFIX_PATH=" + str(root / "dependency")]
    key = subprocess.check_output(command, text=True).strip()
    assert subprocess.check_output(command, text=True).strip() == key
    altered = command.copy()
    altered[-2] = "-DFIXTURE=OFF"
    assert subprocess.check_output(altered, text=True).strip() != key
    marker.write_text("dependency-two\n")
    assert subprocess.check_output(command, text=True).strip() != key
    marker.write_text("dependency-one\n")
    (root / "cache/.tdvp-source-key").write_text(key + "\n")
    (root / "cache/bin/generator").write_text("Fixture output\n")
    shell = 'source "$1"; shift; tdvp_prepare_native_cmake_input "$@"'
    args = ["bash", "-c", shell, "fixture", str(root / "support/native-cmake-input.sh"),
            str(package), str(root / "cache"), "bin/generator", *command[-2:]]
    assert subprocess.run(args, capture_output=True).returncode == 0
    changed = args.copy()
    changed[-2] = "-DFIXTURE=OFF"
    rejected = subprocess.run(changed, capture_output=True)
    assert rejected.returncode == 65 and b"identity differs" in rejected.stderr
    assert (root / "cache/bin/generator").read_text() == "Fixture output\n"
    helper = root / "support/source-archive-library.sh"
    helper.write_text(helper.read_text() + "\n# Updated input policy\n")
    assert subprocess.check_output(command, text=True).strip() != key
    marker.unlink()
    assert subprocess.run(command, capture_output=True).returncode != 0
print("Native cache identity: PASS deterministic reuse, option/helper/dependency changes, missing identity and retained output")
