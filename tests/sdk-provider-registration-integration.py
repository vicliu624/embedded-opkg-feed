"""Run the production builder startup scan with attested fixture providers."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
builder = (source / "scripts/build-all.sh").read_text()
boundary = 'done < <(find "$repo_root/packages" -mindepth 2 -maxdepth 2 -name package.env -type f -print | LC_ALL=C sort)\n'
assert builder.count(boundary) == 1
startup = builder.split(boundary)[0] + boundary
with tempfile.TemporaryDirectory(prefix="tdvp-sdk-provider-registration-") as temporary:
    root = Path(temporary)
    repo = root / "repo"
    repo.mkdir()
    for directory in ("scripts", "support", "platforms"):
        shutil.copytree(source / directory, repo / directory)
    providers = {}
    for name in ("libflac", "libopus-0"):
        package = repo / "packages" / name
        package.mkdir(parents=True)
        shutil.copyfile(source / "packages" / name / "package.env", package / "package.env")
        text = (package / "package.env").read_text()
        version = text.split("VERSION='", 1)[1].split("'", 1)[0]
        providers[name] = version
    records = [row for row in (source / "platforms/tdvp-k230-r1/sdk-development-providers.tsv").read_text().splitlines()
               if row.split("|")[0] in providers]
    assert len(records) == 2
    (repo / "platforms/tdvp-k230-r1/sdk-development-providers.tsv").write_text("\n".join(records) + "\n")
    # Stop only after the unchanged production startup/recipe scan. No build
    # hooks, runtime coverage, or compilation are claimed by this fixture.
    inspection = '\n'
    for row in records:
        name, _, paths = row.split("|")
        inspection += f'[[ "${{sdk_development_provider_files[{name}]}}" == "{paths}" ]] || exit 98\n'
    inspection += 'echo "SDK provider startup scan: PASS retained platform declarations"\n'
    (repo / "scripts/build-all.sh").write_text(startup + inspection)
    base = root / "base"
    base.mkdir()
    output = root / "output"
    feed = output / "tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r11/riscv64"
    feed.mkdir(parents=True)
    for filename in (".tdvp-runtime-owners.tsv", ".tdvp-image-runtime-providers.tsv"):
        (feed / filename).write_text("# Fixture attestation\n")
    (feed / ".tdvp-target-runtime-packages.tsv").write_text("".join(
        f"{name}|{soname}|{providers[name]}\n" for name, soname, _ in (row.split("|") for row in records)))
    (feed / ".tdvp-runtime-catalog-packages.tsv").write_text("".join(
        f"{name}|{version}\n" for name, version in providers.items()))
    env = dict(os.environ, TDVP_FEED_BASE_ROOT=str(base), TDVP_READELF="/usr/bin/true")
    env.pop("TDVP_SDK_ROOT", None)
    command = ["bash", str(repo / "scripts/build-all.sh"), "--platform", "tdvp-k230-r1",
               "--release", "r11", "--output", str(output), "--reuse-runtime-catalog"]
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    for name in providers:
        metadata = repo / "packages" / name / "package.env"
        original = metadata.read_text()
        metadata.write_text(original + "PACKAGE_SDK_DEVELOPMENT_FILES='usr/include/fixture.h'\n")
        rejected = subprocess.run(command, env=env, capture_output=True, text=True)
        assert rejected.returncode == 67, rejected.stdout + rejected.stderr
        assert "duplicates a platform provider: " + name in rejected.stderr
        metadata.write_text(original)
print("SDK provider registration: PASS production startup, FLAC/Opus empty declarations retained and both nonempty duplicates rejected")
