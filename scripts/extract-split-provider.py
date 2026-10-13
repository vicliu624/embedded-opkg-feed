"""Extract only the library and notices required to verify a source split."""
import argparse
import io
from pathlib import Path, PurePosixPath
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("ipk", type=Path)
parser.add_argument("destination", type=Path)
parser.add_argument("--package", required=True)
parser.add_argument("--version", required=True)
parser.add_argument("--library", required=True)
args = parser.parse_args()
destination = args.destination.resolve(strict=True)
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(
        ["ar", "p", str(args.ipk), "control.tar.gz"])), mode="r:gz") as archive:
    members = [m for m in archive.getmembers() if m.name in ("control", "./control")]
    assert len(members) == 1 and members[0].isfile(), "invalid provider control"
    fields = {}
    for line in archive.extractfile(members[0]).read().decode().splitlines():
        if line.startswith((" ", "\t")) or ": " not in line:
            continue
        key, value = line.split(": ", 1)
        assert key not in fields, "duplicate provider control field"
        fields[key] = value
assert fields["Package"] == args.package and fields["Version"] == args.version, "provider identity/version differs"
assert fields["Architecture"] == "riscv64", "provider architecture differs"
prefix = "usr/share/licenses/" + args.package + "/"
found = set()
with tarfile.open(fileobj=io.BytesIO(subprocess.check_output(
        ["ar", "p", str(args.ipk), "data.tar.gz"])), mode="r:gz") as archive:
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        assert not path.is_absolute() and ".." not in path.parts, "unsafe provider archive path"
        relative = path.as_posix()
        if relative != args.library and not relative.startswith(prefix):
            continue
        if member.isdir():
            continue
        assert member.isfile() and relative not in found, "provider needs unique regular library/notice files"
        found.add(relative)
        target = destination / relative
        assert target.resolve().is_relative_to(destination), "provider destination escapes root"
        target.parent.mkdir(parents=True, exist_ok=True)
        with target.open("xb") as stream:
            stream.write(archive.extractfile(member).read())
        target.chmod(member.mode & 0o777)
assert args.library in found and prefix + "SOURCE.json" in found, "provider lacks library/source notice evidence"
print("Split provider extraction: PASS", args.package, len(found), "files")
