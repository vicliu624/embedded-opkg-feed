"""Check every exact runtime edge in the Node cohort against provider recipes."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
consumers = ("libnode", "node", "npm-runtime", "npm", "tdvp-nodejs-tools")
checked = 0
for name in consumers:
    text = (repo / "packages" / name / "package.env").read_text()
    dependencies = re.search(r"^PACKAGE_DEPENDS='([^']*)'", text, re.M)
    assert dependencies, name
    for provider, expected in re.findall(r"([a-z0-9][a-z0-9+.-]*)\s*\(=\s*([^\)]+)\)", dependencies[1]):
        metadata = (repo / "packages" / provider / "package.env").read_text()
        actual = re.search(r"^VERSION='([^']+)'", metadata, re.M)
        assert actual and actual[1] == expected.strip(), (name, provider, expected, actual[1] if actual else None)
        checked += 1
assert checked == 12, checked
print("Node provider version policy: PASS five consumers and twelve exact dependency edges")
