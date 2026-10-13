"""Check real export/import receipts for producers without development files."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path, nargs="?")
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tdvp-command-staging-") as directory:
    root = Path(directory)
    sdk = root / "non-elf-sdk"
    sdk.mkdir()
    if args.sdk:
        # Receipt-only projection preserves actual SDK identity/verifier, with
        # no adjacent image to infer for this non-ELF command fixture.
        actual_sdk = args.sdk.resolve(strict=True)
        for name in ("tdvp-sdk-manifest.json", "verify-sdk.py"):
            shutil.copy2(actual_sdk / name, sdk / name)
    else:
        (sdk / "tdvp-sdk-manifest.json").write_text('{"fixture": "non-ELF receipt identity"}\n')
        # Portable test SDK refuses ELF; a real SDK can be supplied separately.
        (sdk / "verify-sdk.py").write_text('def verify_elf(*args):\n    raise ValueError("non-ELF fixture refuses ELF")\n')
    repo = root / "repo"
    repo.mkdir()
    for name in ("scripts", "support", "platforms"):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns("__pycache__"))
    (repo / "platforms/tdvp-k230-r1/sdk-development-providers.tsv").write_text("# Isolated non-ELF fixture\n")
    for name, dependency in (("fixture-command", ""), ("fixture-consumer", "fixture-command")):
        package = repo / "packages" / name
        package.mkdir(parents=True)
        (package / "package.env").write_text(
            f"PACKAGE='{name}'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
            "MAINTAINER='Fixture'\nDESCRIPTION='Test-only command producer'\n"
            "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='r2'\n"
            "PACKAGE_KIND='application'\nPACKAGE_SECTION='utils'\n"
            f"PACKAGE_BUILD_DEPENDS='{dependency}'\nPACKAGE_AUTO_RUNTIME_DEPENDS=0\n"
            "SOURCE_LOCK_EXEMPT_REASON='Test-only first-party fixture'\n")
        (package / "build.sh").write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'package_dir=$(cd "$(dirname "$0")" && pwd)\n'
            'source "$package_dir/../../support/source-archive-library.sh"\n'
            'payload=$(tdvp_prepare_generated_payload_root "$package_dir")\n'
            'mkdir -p "$payload/usr/share/doc"\n'
            f'printf "fixture\\n" > "$payload/usr/share/doc/{name}"\n'
            f'printf "{name}\\n" >> "$TDVP_FIXTURE_BUILD_LOG"\n')
    log = root / "build.log"
    env = dict(os.environ, TDVP_SDK_ROOT=str(sdk), TDVP_FIXTURE_BUILD_LOG=str(log),
               TDVP_REQUIRE_STAGING_RECEIPT="1", TDVP_FEED_BASE_ROOT="")
    env.pop("TDVP_IMAGE_PROVIDER_MANIFEST", None)
    command = ["bash", str(repo / "scripts/build-all.sh"), "--platform", "tdvp-k230-r1", "--release", "r2"]
    stage = root / "stage"
    first = root / "first"
    result = subprocess.run(command + ["--output", str(first), "--package", "fixture-command",
                                       "--export-staging", str(stage)], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    receipt = json.loads((stage / "tdvp-build-staging-receipt.json").read_text())
    assert receipt["packages"] == ["fixture-command"] and receipt["development_files"] == {}, receipt
    assert (stage / "usr").is_dir()
    second = root / "second"
    for ipk in first.rglob("fixture-command_*.ipk"):
        target = second / ipk.relative_to(first)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ipk, target)
    result = subprocess.run(command + ["--output", str(second), "--package", "fixture-consumer",
                                       "--import-staging", str(stage), "--provided-package", "fixture-command"],
                            env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert log.read_text().splitlines() == ["fixture-command", "fixture-consumer"]
    (stage / "usr/extra").write_text("unrecorded file\n")
    result = subprocess.run(["python3", str(repo / "scripts/build-staging-receipt.py"), "verify",
                             "--repo", str(repo), "--sdk", str(sdk), "--staging", str(stage),
                             "--package", "fixture-command"], env=env, capture_output=True, text=True)
    assert result.returncode != 0 and "development bytes differ" in result.stderr, result.stdout + result.stderr
print("Command staging integration: PASS empty projection, verified reuse, producer skip and tamper rejection")
