"""Exercise normalization without touching a real SDK."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    sdk = root / "sdk"
    private = root / "private"
    sdk.mkdir()
    private.mkdir()
    output = root / "install/usr/lib/pkgconfig"
    output.mkdir(parents=True)
    metadata = output / "fixture.pc"
    metadata.write_text(f"prefix=/usr\nLibs: -lfixture\nLibs.private: -L{private}/usr/lib -lunistring -R{private}/usr/lib -L{sdk}/usr/lib\n")
    command = ["python3", str(repo / "support/normalize-pkgconfig-build-paths.py"), str(root / "install"), "--sysroot", str(sdk), "--sysroot", str(private)]
    subprocess.run(command, check=True)
    normalized = metadata.read_bytes()
    assert str(root).encode() not in normalized
    assert b"-lunistring" in normalized and b"-L/usr/lib" in normalized
    assert b"-R" not in normalized
    subprocess.run(command, check=True)
    assert metadata.read_bytes() == normalized
    removed = root / "removed-producer"
    metadata.write_text(f"Libs.private: -L{removed}/usr/lib -lunistring -R{removed}/usr/lib\n")
    recovery = ["python3", str(repo / "support/normalize-pkgconfig-build-paths.py"),
                str(root / "install"), "--sysroot", str(removed)]
    rejected = subprocess.run(recovery, capture_output=True, text=True)
    assert rejected.returncode != 0 and str(removed) in metadata.read_text()
    subprocess.run(recovery + ["--allow-missing-sysroot"], check=True)
    assert str(removed) not in metadata.read_text() and "-lunistring" in metadata.read_text()
    assert "-R" not in metadata.read_text()
    relative = recovery.copy()
    relative[-1] = "removed-producer"
    assert subprocess.run(relative + ["--allow-missing-sysroot"], capture_output=True).returncode != 0
    metadata.unlink()
    metadata.symlink_to(root / "outside.pc")
    (root / "outside.pc").write_text("outside\n")
    result = subprocess.run(command, capture_output=True, text=True)
    assert result.returncode != 0
    assert (root / "outside.pc").read_text() == "outside\n"
print("pkg-config prefix regression: PASS explicit roots, removed-prefix opt-in, strict defaults, library preservation, idempotence and symlink rejection")
