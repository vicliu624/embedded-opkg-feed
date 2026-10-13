"""Exercise the production owner record parser with LF, CRLF and bad versions."""
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
script = (repo / "scripts/build-runtime-catalog.sh").read_text()
start = script.index("while IFS='|' read -r soname package version; do")
end = script.index('  extra_owner_supports_release "$package" || continue', start)
body = script[start:end] + '  printf "%s|%s|%s\\n" "$soname" "$package" "$version"\ndone < "$1"\n'
with tempfile.TemporaryDirectory() as directory:
    path = Path(directory) / "owners.tsv"
    for ending in (b"\n", b"\r\n"):
        path.write_bytes(b"libz.so.1|libz|1.3.1-1" + ending)
        result = subprocess.run(["bash", "-c", "set -euo pipefail\n" + body, "bash", str(path)], capture_output=True)
        assert result.returncode == 0, result.stderr
        assert result.stdout == b"libz.so.1|libz|1.3.1-1\n", result.stdout
    for version in (b"1.3.1 1", b"1.3.1\rbroken", b""):
        path.write_bytes(b"libz.so.1|libz|" + version + b"\n")
        result = subprocess.run(["bash", "-c", "set -euo pipefail\n" + body, "bash", str(path)], capture_output=True)
        assert result.returncode != 0 and not result.stdout
print("Production runtime-owner parser: PASS LF/CRLF parity and invalid version rejection")
