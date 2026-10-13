"""Static dependency gate regression, including installed held image owners."""
from pathlib import Path
import subprocess
import sys
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts/verify-declared-dependencies.py"
cases = [
    ("consumer", "provider (= 2-1)", "provider", "2-1", "install hold installed", "", True),
    ("consumer", "absent", "provider", "2-1", "install ok installed", "", False),
    ("consumer", "provider (>= 3-1)", "provider", "2-1", "install ok installed", "", False),
    ("consumer", "absent | provider (>= 2-1)", "provider", "2-1", "install ok installed", "", True),
    ("consumer", "provider", "provider", "2-1", "install ok unpacked", "", False),
    ("consumer", "virtual (= 2-1)", "provider", "2-1", "install ok installed", "virtual", False),
    ("consumer", "virtual (= 2-1)", "provider", "2-1", "install ok installed", "virtual (= 2-1)", True),
]
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    for name, depends, provider, version, status, provides, expected in cases:
        index = root / "Packages"
        image = root / "status"
        index.write_text(f"Package: {name}\nVersion: 1-1\nDepends: {depends}\n\n")
        image.write_text(f"Package: {provider}\nVersion: {version}\nStatus: {status}\nProvides: {provides}\n\n")
        result = subprocess.run([sys.executable, str(script), str(index), str(image)], capture_output=True, text=True)
        assert (result.returncode == 0) == expected, (depends, result.stdout, result.stderr)
print("Declared dependency closure regression: PASS", len(cases), "cases")
