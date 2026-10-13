"""Prove a split hook can consume its dependency IPK after payload cleanup."""
import argparse
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
with tempfile.TemporaryDirectory(prefix="tdvp-split-integration-") as directory:
    root = Path(directory)
    repo = root / "repo"
    repo.mkdir()
    for name in ("scripts", "support", "platforms"):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns("__pycache__"))
    (repo / "platforms/tdvp-k230-r1/sdk-development-providers.tsv").write_text("# Non-ELF fixture\n")
    for name, dependency in (("fixture-core", ""), ("fixture-split", "fixture-core")):
        package = repo / "packages" / name
        package.mkdir(parents=True)
        (package / "package.env").write_text(
            "PACKAGE='" + name + "'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
            "MAINTAINER='Fixture'\nDESCRIPTION='Split lifecycle fixture'\n"
            "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='r2'\n"
            "PACKAGE_KIND='development'\nPACKAGE_SECTION='devel'\n"
            "PACKAGE_BUILD_DEPENDS='" + dependency + "'\n"
            "SOURCE_LOCK_EXEMPT_REASON='Test-only first-party fixture'\n")
        hook = (
            "#!/usr/bin/env bash\nset -euo pipefail\n"
            'package_dir=$(cd "$(dirname "$0")" && pwd)\n'
            'source "$package_dir/../../support/source-archive-library.sh"\n')
        if dependency:
            hook += (
                '[[ ! -e "$package_dir/../fixture-core/root" && ! -L "$package_dir/../fixture-core/root" ]]\n'
                '[[ ! -e "$(cat "$TDVP_FIXTURE_PAYLOAD_PATH")" ]]\n'
                'reference=$(mktemp -d)\ntrap \'rm -rf -- "$reference"\' EXIT\n'
                'python3 "$package_dir/../../scripts/extract-split-provider.py" '
                '"$TDVP_FEED_OUTPUT_DIR/fixture-core_1.0-1_riscv64.ipk" "$reference" '
                '--package fixture-core --version 1.0-1 --library usr/include/fixture-core.h\n'
                'grep -Fqx "int fixture_core;" "$reference/usr/include/fixture-core.h"\n')
        hook += (
            'payload=$(tdvp_prepare_generated_payload_root "$package_dir")\n'
            'mkdir -p "$payload/usr/include" "$payload/usr/share/licenses/' + name + '"\n'
            'printf "int fixture_core;\\n" > "$payload/usr/include/' + name + '.h"\n'
            'printf "{}\\n" > "$payload/usr/share/licenses/' + name + '/SOURCE.json"\n')
        if not dependency:
            hook += 'printf "%s\\n" "$payload" > "$TDVP_FIXTURE_PAYLOAD_PATH"\n'
        (package / "build.sh").write_text(hook)
    # SDK manifest/payload checks still use the original SDK. Only incidental
    # sibling-target discovery is isolated from the non-ELF fixture.
    view = root / "sdk"
    view.symlink_to(sdk, target_is_directory=True)
    env = dict(os.environ, TDVP_SDK_ROOT=str(view), TDVP_FIXTURE_PAYLOAD_PATH=str(root / "payload-path"))
    env.pop("TDVP_FEED_BASE_ROOT", None)
    result = subprocess.run([
        "bash", str(repo / "scripts/build-all.sh"), "--platform", "tdvp-k230-r1",
        "--release", "r2", "--output", str(root / "output"), "--package", "fixture-split"],
        env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert len(list((root / "output").rglob("fixture-*_1.0-1_riscv64.ipk"))) == 2
    assert not (repo / "packages/fixture-split/root").exists()
print("Actual split builder: PASS dependency packed, temporary payload removed, IPK consumed, split packed")
