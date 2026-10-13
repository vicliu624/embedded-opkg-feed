"""Keep batch and portable policy gates unified and reject broken release locks."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
batch = (repo / ".github/workflows/build-r10-batch-candidate.yml").read_text()
portable = (repo / ".github/workflows/ci.yml").read_text()
entrypoint = "bash scripts/check-batch-build-policy.sh"
assert batch.count(entrypoint) == 2, "both runtime-base and source-build must use shared policy"
assert portable.count(entrypoint) == 1, "portable CI must execute the shared policy"
shared = (repo / "scripts/check-batch-build-policy.sh").read_text()
for policy in ("build-all-source-lock-policy", "audacious-foundation-policy", "audacious-package-policy",
               "archive-package-policy", "target-runtime-provider-deferral-policy", "feed-overlay-composition-policy", "source-lock-policy"):
    assert policy in shared, policy
assert 'verify-source-lock.sh" --repo-root "$repo_root" --all' in shared
metadata = (repo / "platforms/tdvp-k230-r1/platform.env").read_text()
with tempfile.TemporaryDirectory() as directory:
    fixture = Path(directory)
    (fixture / "tests").mkdir()
    platform = fixture / "platforms/tdvp-k230-r1"
    shutil.copytree(repo / "platforms/tdvp-k230-r1", platform)
    for name in ("scripts", "support", "packages", ".github"):
        (fixture / name).symlink_to(repo / name, target_is_directory=True)
    policy = fixture / "tests/target-runtime-provider-deferral-policy.sh"
    shutil.copyfile(repo / "tests/target-runtime-provider-deferral-policy.sh", policy)
    for name in ("tdvp-gba-source-archive-policy.sh", "sdl2-pulseaudio-patch-policy.sh"):
        (fixture / "tests" / name).symlink_to(repo / "tests" / name)
    for suffix, expected in (("", None), ("\nIMAGE_OWNERSHIP_MANIFEST_SHA256=invalid\n", "needs a SHA256 digest"),
                             ("\nIMAGE_OWNERSHIP_MANIFEST_URL=https://example.invalid/wrong-release.json\n", "same immutable release")):
        (platform / "platform.env").write_text(metadata + suffix)
        result = subprocess.run(["bash", str(policy)], env=os.environ.copy(), capture_output=True, text=True)
        if expected:
            assert result.returncode != 0 and expected in result.stderr, result.stdout + result.stderr
        else:
            assert result.returncode == 0, result.stdout + result.stderr
print("Shared batch policy: PASS workflow coverage, current release acceptance and invalid/mismatched lock rejection")
