"""Exercise the actual transport on POSIX plus hostile archive rejection."""
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tarfile
import tempfile

repo = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("transport", repo / "scripts/staging-artifact.py")
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)
with tempfile.TemporaryDirectory() as temporary:
    base = Path(temporary)
    root = base / "stage"
    (root / "usr/lib/icu/76").mkdir(parents=True)
    (root / "usr/lib/icu/76/data").write_bytes(b"ICU fixture")
    (root / "usr/lib/icu/current").symlink_to("76", target_is_directory=True)
    (root / "usr/bin").mkdir()
    command = root / "usr/bin/bzgrep"
    command.write_bytes(b"command fixture")
    command.chmod(0o755)
    (root / "usr/bin/bzegrep").symlink_to("bzgrep")
    (root / "usr/bin/chain").symlink_to("bzegrep")
    os.link(command, root / "usr/bin/hardcopy")
    for name in ("IO_URING_CHECK_VERSION.3", "io_uring_check_version.3"):
        path = root / "usr/share/man/man3" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(name)
        path.chmod(0o644)
    receipt = {"schema": 1, "development_files": transport.inventory(root)}
    (root / "tdvp-build-staging-receipt.json").write_text(json.dumps(receipt))
    archive = base / "stage.tar.gz"
    transport.pack(root, archive)
    restored = base / "restored"
    transport.unpack(archive, restored)
    assert transport.inventory(restored) == receipt["development_files"]
    assert (restored / "usr/lib/icu/current/data").read_bytes() == b"ICU fixture"
    assert (restored / "tdvp-build-staging-receipt.json").read_bytes() == (root / "tdvp-build-staging-receipt.json").read_bytes()
    for scenario in ("changed-content", "changed-mode", "changed-link"):
        altered = base / (scenario + ".tar.gz")
        with tarfile.open(archive, "r:gz") as original, tarfile.open(altered, "w:gz") as modified:
            for entry in original.getmembers():
                payload = original.extractfile(entry).read() if entry.isfile() else None
                if entry.name == "usr/bin/bzgrep" and scenario == "changed-content":
                    payload = b"altered payload"
                    entry.size = len(payload)
                if entry.name == "usr/bin/bzgrep" and scenario == "changed-mode":
                    entry.mode = 0o644
                if entry.name == "usr/bin/bzegrep" and scenario == "changed-link":
                    entry.linkname = "hardcopy"
                modified.addfile(entry, io.BytesIO(payload) if payload is not None else None)
        # A self-consistent archive checksum cannot override the build receipt.
        altered.with_name(altered.name + ".sha256").write_text(transport.digest(altered))
        output = base / (scenario + "-out")
        try:
            transport.unpack(altered, output)
        except ValueError:
            pass
        else:
            raise AssertionError("accepted receipt mismatch: " + scenario)
        assert not output.exists()
    for scenario in ("traversal", "absolute", "link-parent", "external-link", "special", "duplicate", "bad-receipt", "bad-hash"):
        hostile = base / (scenario + ".tar.gz")
        with tarfile.open(hostile, "w:gz") as tar:
            entry = tarfile.TarInfo("usr/file")
            entry.mode = 0o644
            entry.size = 1
            if scenario == "traversal": entry.name = "../escape"
            if scenario == "absolute": entry.name = "/escape"
            if scenario in ("link-parent", "external-link"):
                link = tarfile.TarInfo("usr/link")
                link.type = tarfile.SYMTYPE
                link.linkname = "directory" if scenario == "link-parent" else "../../escape"
                tar.addfile(link)
                entry.name = "usr/link/file"
            if scenario == "special": entry.type = tarfile.FIFOTYPE; entry.size = 0
            tar.addfile(entry, io.BytesIO(b"x"))
            if scenario == "duplicate": tar.addfile(entry, io.BytesIO(b"x"))
        checksum = hostile.with_name(hostile.name + ".sha256")
        checksum.write_text(transport.digest(hostile) if scenario != "bad-hash" else "0" * 64)
        output = base / (scenario + "-out")
        try:
            transport.unpack(hostile, output)
        except (ValueError, FileNotFoundError):
            pass
        else:
            raise AssertionError("accepted hostile archive: " + scenario)
        assert not output.exists()
    workflow = (repo / ".github/workflows/build-r10-batch-candidate.yml").read_text()
    assert "scripts/staging-artifact.py pack candidate-staging" in workflow
    assert 'scripts/staging-artifact.py unpack "${staging_archives[0]}"' in workflow
    assert "            candidate-staging\n" not in workflow
print("staging-artifact-roundtrip: PASS links, directory links, case, modes, hard-linked files and eleven rejection cases")
