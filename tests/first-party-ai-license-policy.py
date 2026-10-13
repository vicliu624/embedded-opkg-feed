"""Keep the approved first-party MIT license in every AI package payload."""
from pathlib import Path

repo = Path(__file__).resolve().parents[1]
names = ("libtdvp-ai-client", "python3-tdvp-ai", "tdvp-ai-tools")
licenses = []
for name in names:
    package = repo / "packages" / name
    license_text = (package / "LICENSE").read_text().replace("\r\n", "\n")
    assert license_text.startswith("MIT License\n"), name
    assert "Permission is hereby granted, free of charge" in license_text, name
    assert "THE SOFTWARE IS PROVIDED \"AS IS\"" in license_text, name
    licenses.append(license_text)
    metadata = (package / "package.env").read_text()
    assert "PACKAGE_LICENSE='MIT'" in metadata, name
    assert "VERSION='0.1.0-2'" in metadata, name
    hook = (package / "build.sh").read_text()
    assert f'install -m 0644 "$package_dir/LICENSE" "$payload/usr/share/licenses/{name}/LICENSE"' in hook, name
assert len(set(licenses)) == 1, "first-party MIT license texts drifted"
tools_metadata = (repo / "packages/tdvp-ai-tools/package.env").read_text()
assert "python3-tdvp-ai (= 0.1.0-2)" in tools_metadata
print("First-party AI MIT license policy: PASS three recipes, payload hooks and revision dependency")
