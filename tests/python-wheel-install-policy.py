"""Wheel data installation must preserve metadata and reject unsafe paths."""
import pathlib
import stat
import subprocess
import sys
import tempfile
import zipfile

installer = pathlib.Path(__file__).resolve().parents[1] / "scripts/install-python-wheel.py"
with tempfile.TemporaryDirectory(prefix="tdvp-wheel-policy-") as temporary:
    root = pathlib.Path(temporary)
    valid = root / "valid.whl"
    with zipfile.ZipFile(valid, "w") as archive:
        archive.writestr("demo/__init__.py", "value = 42\n")
        archive.writestr("demo-1.dist-info/METADATA", "Name: demo\nVersion: 1\n")
        archive.writestr("demo-1.data/data/share/man/man1/demo.1", "manual")
        archive.writestr("demo-1.data/purelib/extra.py", "value = 1\n")
    payload = root / "valid-payload"
    subprocess.run([sys.executable, str(installer), str(valid), str(payload)], check=True)
    assert (payload / "usr/share/man/man1/demo.1").read_text() == "manual"
    assert (payload / "usr/lib/python3.13/site-packages/extra.py").is_file()
    for index, malicious in enumerate([
        "../outside", "/etc/passwd", "demo-1.data/data/../../outside",
        "demo-1.data/data/etc/passwd", "demo-1.data/scripts/unsafe",
        "demo\\outside", "demo/nested.data/unsafe",
    ]):
        wheel = root / f"invalid-{index}.whl"
        with zipfile.ZipFile(wheel, "w") as archive:
            archive.writestr("demo.py", "valid-first-member")
            archive.writestr(malicious, "unsafe")
        output = root / f"invalid-payload-{index}"
        result = subprocess.run([sys.executable, str(installer), str(wheel), str(output)], capture_output=True)
        assert result.returncode != 0, malicious
        assert not output.exists(), "unsafe archive was partially installed"
    wheel = root / "symlink.whl"
    with zipfile.ZipFile(wheel, "w") as archive:
        entry = zipfile.ZipInfo("demo.py")
        entry.create_system = 3
        entry.external_attr = (stat.S_IFLNK | 0o777) << 16
        archive.writestr(entry, "../../etc/passwd")
    result = subprocess.run([sys.executable, str(installer), str(wheel), str(root / "symlink-payload")], capture_output=True)
    assert result.returncode != 0
    wheel = root / "collision.whl"
    with zipfile.ZipFile(wheel, "w") as archive:
        archive.writestr("demo.py", "first")
        archive.writestr("demo-1.data/purelib/demo.py", "collision")
    result = subprocess.run([sys.executable, str(installer), str(wheel), str(root / "collision-payload")], capture_output=True)
    assert result.returncode != 0
print("Wheel purelib, metadata, share/man mapping and unsafe-path rejection: PASS")
