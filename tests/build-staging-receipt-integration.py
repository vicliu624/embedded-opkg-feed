"""Exercise the actual builder export/import with a tiny non-ELF dependency."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
args = parser.parse_args()
sdk = args.sdk.resolve(strict=True)
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tdvp-staging-integration-") as directory:
    root = Path(directory)
    repo = root / "repo"
    repo.mkdir()
    for name in ("scripts", "support", "platforms"):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns("__pycache__"))
    # This r2 fixture has no platform runtime libraries. The real SDK is used
    # solely for payload/receipt validation; runtime catalogue coverage is a
    # separate full-platform gate exercised on the matched complete feed.
    (repo / "platforms/tdvp-k230-r1/sdk-development-providers.tsv").write_text("# No runtime providers in the non-ELF fixture\n")
    for name, dependency in (("fixture-dep", ""), ("fixture-consumer", "fixture-dep")):
        package = repo / "packages" / name
        (package / "src").mkdir(parents=True)
        (package / "src/fixture.h").write_text("int fixture;\n")
        (package / "package.env").write_text(
            "PACKAGE='" + name + "'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
            "MAINTAINER='Fixture'\nDESCRIPTION='Fixture development input'\n"
            "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='r2'\n"
            "PACKAGE_KIND='development'\nPACKAGE_SECTION='devel'\n"
            "PACKAGE_BUILD_DEPENDS='" + dependency + "'\n"
            "SOURCE_LOCK_EXEMPT_REASON='Test-only first-party fixture'\n")
        (package / "build.sh").write_text(
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            'package_dir=$(cd "$(dirname "$0")" && pwd)\n'
            'source "$package_dir/../../support/source-archive-library.sh"\n'
            'payload=$(tdvp_prepare_generated_payload_root "$package_dir")\n'
            'mkdir -p "$payload/usr/include" "$TDVP_FEED_STAGING_ROOT/usr/include"\n'
            'cp "$package_dir/src/fixture.h" "$payload/usr/include/' + name + '.h"\n'
            'cp "$payload/usr/include/' + name + '.h" "$TDVP_FEED_STAGING_ROOT/usr/include/"\n'
            'printf "' + name + '\\n" >> "$TDVP_FIXTURE_BUILD_LOG"\n')
    log = root / "build.log"
    # Keep the real SDK bytes/receipt identity, but isolate its parent's target
    # discovery from this non-ELF fixture. No production coverage gate is skipped.
    view = root / "sdk"
    view.symlink_to(sdk, target_is_directory=True)
    env = dict(os.environ, TDVP_SDK_ROOT=str(view), TDVP_FIXTURE_BUILD_LOG=str(log),
               TDVP_REQUIRE_STAGING_RECEIPT="1")
    env.pop("TDVP_FEED_BASE_ROOT", None)
    command = ["bash", str(repo / "scripts/build-all.sh"), "--platform", "tdvp-k230-r1", "--release", "r2"]
    stage = root / "exported"
    result = subprocess.run(command + ["--output", str(root / "first"), "--package", "fixture-dep",
                                      "--export-staging", str(stage)], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    receipt = json.loads((stage / "tdvp-build-staging-receipt.json").read_text())
    assert "fixture-dep" in receipt["packages"]
    imported = root / "second"
    imported.mkdir()
    for p in (root / "first").rglob("fixture-dep_*.ipk"):
        target = imported / p.relative_to(root / "first")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, target)
    reuse = command + ["--output", str(imported), "--package", "fixture-consumer",
                       "--import-staging", str(stage), "--provided-package", "fixture-dep"]
    result = subprocess.run(reuse, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert log.read_text().splitlines() == ["fixture-dep", "fixture-consumer"], log.read_text()
    (stage / "usr/include/fixture-dep.h").write_text("tampered\n")
    rejected = command + ["--output", str(root / "rejected"), "--package", "fixture-consumer",
                          "--import-staging", str(stage), "--provided-package", "fixture-dep"]
    result = subprocess.run(rejected, env=env, capture_output=True, text=True)
    assert result.returncode != 0 and "development bytes differ" in result.stderr, result.stdout + result.stderr
    assert log.read_text().splitlines() == ["fixture-dep", "fixture-consumer"]
print("Actual builder staging integration: PASS export, verified import, dependency skip and byte-change rejection")
