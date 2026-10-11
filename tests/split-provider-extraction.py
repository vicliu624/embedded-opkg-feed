"""Exercise split-provider identity, notice and archive safety gates."""
import io
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/extract-split-provider.py"
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    for case in ("valid", "identity", "version", "architecture", "traversal", "symlink", "duplicate", "missing-notice"):
        work = root / case
        work.mkdir()
        destination = work / "output"
        destination.mkdir()
        control = "Package: %s\nVersion: %s\nArchitecture: %s\n" % (
            "other" if case == "identity" else "libelf-1",
            "2" if case == "version" else "1",
            "amd64" if case == "architecture" else "riscv64")
        library = "usr/lib/libelf.so.1"
        entries = [(library, b"fixture library"),
                   ("usr/share/licenses/libelf-1/SOURCE.json", b"{}")]
        if case == "traversal":
            entries.append(("../outside", b"unsafe"))
        if case == "duplicate":
            entries.append(entries[0])
        if case == "missing-notice":
            entries.pop()
        for archive_name, records in (("control.tar.gz", [("control", control.encode())]),
                                      ("data.tar.gz", entries)):
            with tarfile.open(work / archive_name, "w:gz") as archive:
                for name, payload in records:
                    member = tarfile.TarInfo(name)
                    member.size = len(payload)
                    if case == "symlink" and name == library:
                        member.type = tarfile.SYMTYPE
                        member.linkname = "/etc/passwd"
                        member.size = 0
                        archive.addfile(member)
                    else:
                        archive.addfile(member, io.BytesIO(payload))
        ipk = work / "provider.ipk"
        subprocess.run(["ar", "rc", str(ipk), "control.tar.gz", "data.tar.gz"],
                       cwd=work, check=True, capture_output=True)
        result = subprocess.run([sys.executable, str(script), str(ipk), str(destination),
                                 "--package", "libelf-1", "--version", "1", "--library", library],
                                capture_output=True)
        assert (result.returncode == 0) == (case == "valid"), (case, result.stderr)
        assert not (work / "outside").exists()
        if case == "valid":
            assert (destination / library).read_bytes() == b"fixture library"
print("Split provider regression: PASS identity, version, architecture, traversal, symlink, duplicate, notices")
