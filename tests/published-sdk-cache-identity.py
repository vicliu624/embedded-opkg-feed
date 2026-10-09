"""Execute the shared action's cache identity export against changing SDK locks."""
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
action = (repo / ".github/actions/published-sdk/action.yml").read_text()
step = action.split("    - name: Export verified SDK cache identity\n", 1)[1]
body = step.split("      run: |\n", 1)[1].split("    - name:", 1)[0]
body = "\n".join(line[8:] for line in body.splitlines() if line.strip())
assert action.index("Verify and prepare published inputs") < action.index("Export verified SDK cache identity")
workflow = (repo / ".github/workflows/build-r10-batch-candidate.yml").read_text()
assert "TDVP_SDK_CACHE_KEY: tdvp-published-sdk-" not in workflow, "hardcoded SDK identity"
assert workflow.count("uses: ./.github/actions/published-sdk") == 3
with tempfile.TemporaryDirectory() as directory:
    fixture = Path(directory)
    platform = fixture / "platforms/tdvp-k230-r1"
    platform.mkdir(parents=True)
    for digest in ("a" * 64, "b" * 64, "invalid"):
        (platform / "platform.env").write_text(f"SDK_ARCHIVE_SHA256='{digest}'\n")
        output = fixture / (digest + ".env")
        result = subprocess.run(["bash", "-c", body], cwd=fixture,
                                env=dict(os.environ, GITHUB_ENV=str(output)), capture_output=True, text=True)
        if digest == "invalid":
            assert result.returncode != 0 and not output.exists()
        else:
            assert result.returncode == 0, result.stderr
            assert output.read_text() == f"TDVP_SDK_CACHE_KEY=tdvp-published-sdk-{digest}\n"
print("Published SDK cache identity: PASS actual action follows platform lock; malformed digest rejected")
