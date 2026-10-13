"""Exercise shared helper RETURN-trap lifetimes with non-ELF fixtures."""
from pathlib import Path
import shutil
import subprocess
import tempfile

source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="tdvp-notice-lifetime-") as directory:
    root = Path(directory)
    repo = root / "repo"
    shutil.copytree(source / "support", repo / "support")
    sdk = root / "sdk"
    (sdk / "bin").mkdir(parents=True)
    (sdk / "tdvp-sdk-manifest.json").write_text('{"fixture": "non-ELF lifetime test"}\n')
    readelf = sdk / "bin/riscv64-unknown-linux-gnu-readelf"
    readelf.write_text('#!/bin/sh\nexit 1\n')
    readelf.chmod(0o755)
    # No source compilation or ELF attestation occurs in this fixture.
    (repo / "support/published-sdk-build.sh").write_text(
        'tdvp_sdk_install() {\n'
        ' mkdir -p "$4/usr/bin" "$4/usr/lib" "$4/usr/share/licenses/$3"\n'
        ' printf "#!/bin/sh\\necho fixture\\n" > "$4/usr/bin/fixture"\n'
        ' chmod 755 "$4/usr/bin/fixture"\n'
        ' printf "non-ELF fixture data\\n" > "$4/usr/lib/libfixture.so"\n'
        ' printf "Original notice bytes\\r\\n" > "$4/usr/share/licenses/$3/COPYING"\n'
        '}\n')
    for name, helper, function, tail in (
        ('fixture-command', 'buildroot-command-package.sh', 'tdvp_buildroot_command_package', 'BR2_PACKAGE_FIXTURE fixture "FIXTURE_VERSION = 1" fixture'),
        ('fixture-library', 'buildroot-archive-library.sh', 'tdvp_build_archive_library', 'BR2_PACKAGE_FIXTURE fixture "libfixture.so*" "FIXTURE_VERSION = 1"'),
    ):
        package = repo / "packages" / name
        package.mkdir(parents=True)
        shell = f'source "$1"; {function} "$2" "$3" "" {tail}'
        result = subprocess.run(['bash', '-Eeuo', 'pipefail', '-c', shell, 'fixture',
                                 str(repo / 'support' / helper), str(package), str(sdk)],
                                capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
        payload = package / "root"
        assert payload.is_dir(), "RETURN cleanup removed completed payload"
        notice = payload / 'usr/share/licenses' / name / 'COPYING'
        assert notice.read_bytes() == b'Original notice bytes\r\n'
        expected = payload / ('usr/libexec/tdvp-fixture-command/fixture' if name == 'fixture-command' else 'usr/lib/libfixture.so')
        assert expected.is_file(), "RETURN cleanup removed runtime fixture"
        # Payloads are generated outside the fixture repo; retain no residue.
        destination = payload.resolve()
        assert destination.name.startswith('tdvp-command-payload.')
        assert destination.parent == Path(tempfile.gettempdir()).resolve()
        shutil.rmtree(destination)
print('Notice projection lifetime: PASS command/library payload survival and original bytes (non-ELF fixtures)')
