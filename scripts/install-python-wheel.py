"""Install audited wheel paths into an empty target payload, never the host."""
import pathlib
import shutil
import stat
import sys
import zipfile

wheel, payload = map(pathlib.Path, sys.argv[1:])
site = pathlib.PurePosixPath("usr/lib/python3.13/site-packages")
planned = []
seen = set()
with zipfile.ZipFile(wheel) as archive:
    for entry in archive.infolist():
        name = pathlib.PurePosixPath(entry.filename)
        if (name.is_absolute() or ".." in name.parts or "\\" in entry.filename
                or not name.parts or stat.S_ISLNK(entry.external_attr >> 16)):
            raise ValueError("unsafe wheel member: " + entry.filename)
        if name.parts[0].endswith(".data"):
            if len(name.parts) < 3:
                if entry.is_dir():
                    continue
                raise ValueError("incomplete wheel data path: " + entry.filename)
            scheme, relative = name.parts[1], pathlib.PurePosixPath(*name.parts[2:])
            if scheme in ("purelib", "platlib"):
                target = site / relative
            elif scheme == "data" and relative.parts[0] == "share":
                target = pathlib.PurePosixPath("usr") / relative
            else:
                raise ValueError("unreviewed wheel installation scheme: " + entry.filename)
        else:
            if any(part.endswith(".data") for part in name.parts):
                raise ValueError("nested wheel data scheme: " + entry.filename)
            target = site / name
        if entry.is_dir():
            continue
        if target in seen or (payload / target).exists():
            raise ValueError("colliding wheel destination: " + str(target))
        seen.add(target)
        planned.append((entry, target))
    # Validate every member before creating any payload files.
    for entry, relative in planned:
        target = payload / relative
        for parent in target.parents:
            if parent == payload:
                break
            if parent.is_symlink():
                raise ValueError("symlink in payload destination")
        target.parent.mkdir(parents=True, exist_ok=True)
        with archive.open(entry) as source, target.open("xb") as destination:
            shutil.copyfileobj(source, destination)
        target.chmod(0o644)
