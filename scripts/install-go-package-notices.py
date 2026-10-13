"""Preserve upstream, Go and vendored notices without asserting legal clearance."""
import argparse
import fnmatch
import hashlib
import json
from pathlib import Path
import shutil

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--source", type=Path, required=True)
parser.add_argument("--go-root", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
source = args.source.resolve(strict=True)
go = args.go_root.resolve(strict=True)
output = args.output
assert not output.exists() and not output.is_symlink(), "refusing existing notice output"
vendor = source / "vendor"
assert vendor.is_dir() and not vendor.is_symlink(), "missing verified vendor tree"
notices = [(source / "LICENSE", "LICENSE"), (go / "LICENSE", "Go-LICENSE")]
if (go / "PATENTS").is_file():
    notices.append((go / "PATENTS", "Go-PATENTS"))
patterns = ("LICENSE*", "LICENCE*", "COPYING*", "NOTICE*", "PATENTS*", "COPYRIGHT*", "AUTHORS*")
vendor_records = []
for path in sorted(vendor.rglob("*")):
    if not any(fnmatch.fnmatchcase(path.name.upper(), pattern) for pattern in patterns):
        continue
    if path.is_dir():
        continue
    assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(vendor), "unsafe notice path"
    relative = path.relative_to(source).as_posix()
    notices.append((path, relative))
    vendor_records.append(path.relative_to(vendor).as_posix())
assert vendor_records, "vendor tree has no notices"
records = []
for path, relative in notices:
    assert path.is_file() and not path.is_symlink(), "missing or unsafe mandatory notice: " + str(path)
    destination = output / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, destination)
    destination.chmod(0o644)
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    records.append({"path": relative, "sha256": digest})
modules = sorted({line.split()[1] for line in (vendor / "modules.txt").read_text().splitlines()
                  if line.startswith("# ") and len(line.split()) >= 3 and line.split()[2] != "=>"})
materialized = [module for module in modules if (vendor / module).is_dir()]
not_materialized = [module for module in modules if module not in materialized]
uncovered = [module for module in materialized if not any(path.startswith(module + "/") for path in vendor_records)]
report = {"schema": 1, "notice_files": records, "vendor_modules": modules,
          "materialized_vendor_modules": materialized,
          "modules_without_vendor_sources": not_materialized,
          "modules_without_direct_notice": uncovered,
          "scope": "Notice preservation inventory; module license and redistribution review required separately."}
(output / "notice-inventory.json").write_text(json.dumps(report, sort_keys=True, indent=2) + "\n")
print("Go notice inventory:", len(records), "files,", len(materialized), "materialized modules,", len(uncovered), "without direct notices")
