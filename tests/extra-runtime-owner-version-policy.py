"""Reject stale non-base provider versions before the strict runtime registry."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
checked = 0
for line in (repo / "platforms/tdvp-k230-r1/extra-runtime-owners.tsv").read_text().splitlines():
    if not line or line.startswith("#"):
        continue
    soname, package, declared = line.split("|")
    recipe = repo / "packages" / package / "package.env"
    if not recipe.is_file():
        continue
    text = recipe.read_text()
    releases = re.search(r"^PACKAGE_RELEASES='([^']+)'", text, re.M)
    if not releases or "r11" not in releases[1].split():
        continue
    version = re.search(r"^VERSION='([^']+)'", text, re.M)
    assert version and version[1] == declared, (soname, package, declared, version[1] if version else None)
    checked += 1
assert checked > 0
print("Extra runtime owner versions: PASS", checked, "eligible source SONAME declarations match recipes")
