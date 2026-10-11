"""Execute the actual workflow selection block without compiling packages."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
workflow = (repo / ".github/workflows/build-r10-batch-candidate.yml").read_text()
contract = json.loads((repo / "support/ai-common-library-cohort.json").read_text())
packages = [name for group in contract["groups"].values() for name in group]
assert packages and len(packages) == len(set(packages))
selection_start = workflow.index("            ai-common)\n              mapfile -t expected_packages")
body = workflow[selection_start:].split("            ai-common)", 1)[1].split("\n              ;;", 1)[0]
expected = ["--export-staging", "candidate-staging"]
for name in packages:
    expected += ["--package", name]
with tempfile.TemporaryDirectory() as directory:
    command = ["bash", "-c", "set -Eeuo pipefail\n" + body +
               '\nprintf "%s\\n" "${package_args[@]}"\n']
    environment = dict(os.environ, RUNNER_TEMP=directory)
    result = subprocess.run(command, cwd=repo, env=environment, capture_output=True, text=True, check=True)
    assert result.stdout.splitlines() == expected, result.stdout
    imported = Path(directory) / "tdvp-audacious-import"
    imported.mkdir()
    (imported / "tdvp-build-staging-receipt.json").write_text(json.dumps({"packages": ["libfmt"]}))
    result = subprocess.run(command, cwd=repo, env=environment, capture_output=True, text=True, check=True)
    reused = expected[:2] + ["--import-staging", str(imported), "--provided-package", "libfmt"] + expected[2:]
    assert result.stdout.splitlines() == reused, result.stdout
assert workflow.index("Reject incomplete AI platform inputs before compilation") < workflow.index("Prepare the pinned native AI Python host")
assert "cancel-in-progress: false" in workflow
print("Actual AI/common workflow selection: PASS", len(packages), "packages, staging export and SDK-first order")
