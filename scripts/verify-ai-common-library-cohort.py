"""Validate required delivery recipes and, optionally, final index coverage."""
import argparse
import json
from pathlib import Path
import re

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument("--feed", type=Path)
args = parser.parse_args()
repo = args.repo_root.resolve(strict=True)
contract = json.loads((repo / "support/ai-common-library-cohort.json").read_text())
assert contract["schema"] == 1 and contract["release"] == "r11"
required = [name for group in contract["groups"].values() for name in group]
assert len(required) == len(set(required)), "duplicate delivery package"
problems = []
for name in required:
    assert re.fullmatch(r"[a-z0-9][a-z0-9+.-]*", name), name
    package = repo / "packages" / name
    metadata = package / "package.env"
    if not metadata.is_file():
        problems.append(name + ": missing recipe")
        continue
    text = metadata.read_text()
    if "PACKAGE='" + name + "'" not in text:
        problems.append(name + ": recipe identity mismatch")
    if not (package / "build.sh").is_file():
        problems.append(name + ": missing build hook")
    exemption = re.search(r"^SOURCE_LOCK_EXEMPT_REASON='([^']+)'", text, re.M)
    if not (package / "source.lock").is_file() and not exemption:
        problems.append(name + ": missing source lock or explicit first-party exemption")
    match = re.search(r"^PACKAGE_BUILD_DEPENDS='([^']*)'", text, re.M)
    for dependency in (match[1].split() if match else []):
        if not (repo / "packages" / dependency / "package.env").is_file():
            problems.append(name + ": unknown build dependency " + dependency)
if args.feed:
    index = (args.feed / "Packages").read_text()
    delivered = set(re.findall(r"^Package: (.+)$", index, re.M))
    problems += [name + ": absent from final index" for name in required if name not in delivered]
if problems:
    raise SystemExit("AI/common-library delivery inventory failed:\n" + "\n".join(problems))
print("AI/common-library delivery inventory: PASS", len(required), "required recipes",
      "and final index" if args.feed else "(index coverage not checked)")
