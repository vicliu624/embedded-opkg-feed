"""Check exact source-to-source version edges across all eligible r11 recipes.

Final image providers and virtual aliases are verified by the actual IPK
closure gates; this source-level check does not replace those gates.
"""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
recipes = {}
sdk_supplied = set()
for metadata in (repo / "packages").glob("*/package.env"):
    text = metadata.read_text()
    fields = dict(re.findall(r"^([A-Z_]+)='([^']*)'", text, re.M))
    if "r11" in fields.get("PACKAGE_RELEASES", "").split():
        recipes[metadata.parent.name] = fields
        if re.search(r"^PACKAGE_SOURCE_STAGING=0\s*$", text, re.M) and fields.get("PACKAGE_SDK_DEVELOPMENT_FILES"):
            sdk_supplied.add(metadata.parent.name)
checked = 0
for package, fields in recipes.items():
    if package in sdk_supplied:
        continue
    for provider, expected in re.findall(r"([a-z0-9][a-z0-9+.-]*)\s*\(=\s*([^\)]+)\)", fields.get("PACKAGE_DEPENDS", "")):
        if provider not in recipes:
            continue
        actual = recipes[provider].get("VERSION")
        assert actual == expected.strip(), (package, provider, expected, actual)
        checked += 1
assert checked > 0
print("Source recipe exact dependencies: PASS", len(recipes), "eligible recipes and", checked, "source-provider edges")
print("SDK-supplied consumers verified by image/IPK closure:", ", ".join(sorted(sdk_supplied)) or "none")
