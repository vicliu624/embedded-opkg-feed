"""Exercise explicit recovery import, producer export and ordinary receipt reuse.

The r2 fixture isolates packaging from full-image catalogue coverage. Real SDK,
source and SQLite IPK bytes are used; its runtime builder fails if called.
"""
import argparse
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
parser.add_argument('archive', type=Path)
parser.add_argument('ipk', type=Path)
parser.add_argument('--image', type=Path)
parser.add_argument('--catalogue', type=Path)
parser.add_argument('--consumer-output', type=Path)
args = parser.parse_args()
assert bool(args.image) == bool(args.catalogue)
assert not args.consumer_output or args.image
release = 'r11' if args.image else 'r2'
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-recovered-builder-') as directory:
    root = Path(directory)
    repo = root / 'repo'
    repo.mkdir()
    for name in ('scripts', 'support', 'platforms'):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns('__pycache__'))
    if not args.image:
        (repo / 'platforms/tdvp-k230-r1/sdk-development-providers.tsv').write_text('# Isolated r2 fixture\n')
    sqlite = repo / 'packages/libsqlite3-0'
    shutil.copytree(source / 'packages/libsqlite3-0', sqlite, ignore=shutil.ignore_patterns('root'))
    env_file = sqlite / 'package.env'
    if not args.image:
        env_file.write_text(env_file.read_text().replace("PACKAGE_RELEASES='r10 r11'", "PACKAGE_RELEASES='r2'"))
    (sqlite / 'build.sh').write_text('#!/usr/bin/env bash\necho SQLITERUNTIME_REBUILD_FORBIDDEN >&2\nexit 88\n')
    consumer = repo / 'packages/fixture-consumer'
    consumer.mkdir()
    (consumer / 'package.env').write_text(
        "PACKAGE='fixture-consumer'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
        "MAINTAINER='Fixture'\nDESCRIPTION='Recovered header consumer'\n"
        "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='" + release + "'\n"
        "PACKAGE_KIND='" + ('application' if args.consumer_output else 'development') + "'\nPACKAGE_SECTION='devel'\n"
        "PACKAGE_BUILD_DEPENDS='libsqlite3-0'\nSOURCE_LOCK_EXEMPT_REASON='Test-only fixture'\n")
    (consumer / 'build.sh').write_text(
        '#!/usr/bin/env bash\nset -euo pipefail\n'
        'package_dir=$(cd "$(dirname "$0")" && pwd)\n'
        'source "$package_dir/../../support/source-archive-library.sh"\n'
        'test -f "$TDVP_FEED_STAGING_ROOT/usr/include/sqlite3.h"\n'
        'test -f "$TDVP_FEED_STAGING_ROOT/usr/lib/libsqlite3.so"\n'
        'payload=$(tdvp_prepare_generated_payload_root "$package_dir")\n'
        'mkdir -p "$payload/usr/include"\n'
        'printf "/* recovered SQLite consumer */\\n" > "$payload/usr/include/fixture-consumer.h"\n')
    if args.consumer_output:
        (consumer / 'src').mkdir()
        shutil.copyfile(source / 'tests/sqlite-development-consumer-smoke.c', consumer / 'src/consumer.c')
        (consumer / 'package.env').write_text((consumer / 'package.env').read_text() + 'PACKAGE_AUTO_RUNTIME_DEPENDS=1\n')
        (consumer / 'build.sh').write_text(
            '#!/usr/bin/env bash\nset -euo pipefail\n'
            'package_dir=$(cd "$(dirname "$0")" && pwd)\n'
            'source "$package_dir/../../support/source-archive-library.sh"\n'
            'payload=$(tdvp_prepare_generated_payload_root "$package_dir")\n'
            'mkdir -p "$payload/usr/bin"\n'
            '"$TDVP_SDK_ROOT/bin/riscv64-unknown-linux-gnu-gcc" --sysroot="$TDVP_SDK_ROOT/sysroot" '
            '-march=rv64imafdc -mabi=lp64d -I"$TDVP_FEED_STAGING_ROOT/usr/include" '
            '"$package_dir/src/consumer.c" -L"$TDVP_FEED_STAGING_ROOT/usr/lib" '
            '-Wl,-rpath-link,"$TDVP_FEED_STAGING_ROOT/usr/lib" -lsqlite3 '
            '-o "$payload/usr/bin/fixture-consumer"\n')
    cache = root / 'source-cache'
    cached = cache / 'sha256/ac992f7fca3989de7ed1fe99c16363f848794c8c32a158dafd4eb927a2e02fd5/sqlite-autoconf-3480000.tar.gz'
    cached.parent.mkdir(parents=True)
    shutil.copyfile(args.archive, cached)
    sdk_view = root / 'sdk'
    sdk_view.symlink_to(args.sdk.resolve(strict=True), target_is_directory=True)
    recovery = root / 'recovered'
    restore = ['python3', str(repo / 'scripts/restore-sqlite-development.py'),
               '--repo', str(repo), '--sdk', str(sdk_view), '--release', release,
               '--source-archive', str(cached), '--runtime-ipk', str(args.ipk), '--output', str(recovery)]
    subprocess.run(restore, check=True)
    env = dict(os.environ, TDVP_SDK_ROOT=str(sdk_view), TDVP_REQUIRE_STAGING_RECEIPT='1')
    env.pop('TDVP_FEED_BASE_ROOT', None)
    if args.image:
        env['TDVP_FEED_BASE_ROOT'] = str(args.image.resolve(strict=True))
    command = ['bash', str(repo / 'scripts/build-all.sh'), '--platform', 'tdvp-k230-r1',
               '--release', release, '--source-cache', str(cache), '--offline-source-cache',
               '--package', 'fixture-consumer', '--provided-package', 'libsqlite3-0']
    first = root / 'first'
    release_path = subprocess.check_output([
        'bash', '-c', 'source "$1/scripts/feed-platform.sh"; tdvp_load_platform "$1" tdvp-k230-r1; tdvp_feed_release_path "$2"',
        'bash', str(repo), release], text=True).strip()
    destination = first / release_path
    destination.mkdir(parents=True)
    if args.catalogue:
        for p in args.catalogue.iterdir():
            if p.is_file() and (p.suffix == '.ipk' or p.name.startswith('.tdvp-')):
                shutil.copyfile(p, destination / p.name)
        command.append('--reuse-runtime-catalog')
    shutil.copyfile(args.ipk, destination / 'libsqlite3-0_3.48.0-1_riscv64.ipk')
    exported = root / 'exported'
    result = subprocess.run(command + ['--output', str(first), '--import-recovered-sqlite', str(recovery),
                                      '--export-staging', str(exported)], env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    if args.consumer_output:
        assert not args.consumer_output.exists()
        payload = subprocess.check_output(['ar', 'p', str(destination / 'fixture-consumer_1.0-1_riscv64.ipk'), 'data.tar.gz'])
        with tarfile.open(fileobj=io.BytesIO(payload), mode='r:gz') as package:
            member = next(m for m in package if m.name.lstrip('./') == 'usr/bin/fixture-consumer')
            assert member.isfile() and member.size < 1000000
            args.consumer_output.parent.mkdir(parents=True, exist_ok=True)
            args.consumer_output.write_bytes(package.extractfile(member).read())
            args.consumer_output.chmod(0o755)
    receipt = json.loads((exported / 'tdvp-build-staging-receipt.json').read_text())
    assert receipt['recovered_development']['runtime_rebuilt'] is False
    assert 'libsqlite3-0' in receipt['packages']
    second = root / 'second'
    if args.catalogue:
        (second / release_path).mkdir(parents=True)
        for p in args.catalogue.glob('.tdvp-*'):
            if p.is_file():
                shutil.copyfile(p, second / release_path / p.name)
    for p in destination.iterdir():
        if not (p.name.startswith('libsqlite3-0_') or (args.image and
                (p.name.startswith('.tdvp-') or (p.suffix == '.ipk' and not p.name.startswith('fixture-consumer_'))))):
            continue
        target = second / p.relative_to(first)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
    result = subprocess.run(command + ['--output', str(second), '--import-staging', str(exported)],
                            env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'SQLITERUNTIME_REBUILD_FORBIDDEN' not in result.stderr
    provenance_file = exported / 'tdvp-development-recovery.json'
    provenance = json.loads(provenance_file.read_text())
    provenance['runtime_ipk_sha256'] = '0' * 64
    provenance_file.write_text(json.dumps(provenance))
    third = root / 'rejected'
    if args.catalogue:
        (third / release_path).mkdir(parents=True)
        for p in args.catalogue.glob('.tdvp-*'):
            if p.is_file():
                shutil.copyfile(p, third / release_path / p.name)
    for p in destination.iterdir():
        if not (p.name.startswith('libsqlite3-0_') or (args.image and
                (p.name.startswith('.tdvp-') or (p.suffix == '.ipk' and not p.name.startswith('fixture-consumer_'))))):
            continue
        target = third / p.relative_to(first)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(p, target)
    rejected = subprocess.run(command + ['--output', str(third), '--import-staging', str(exported)],
                              env=env, capture_output=True, text=True)
    assert rejected.returncode != 0 and 'development bytes differ' in rejected.stderr
    assert 'SQLITERUNTIME_REBUILD_FORBIDDEN' not in rejected.stderr
print('Recovered builder integration: PASS', release, 'verified import, no runtime builder call, provenance-preserving export, ordinary receipt reuse and changed provenance rejection')
