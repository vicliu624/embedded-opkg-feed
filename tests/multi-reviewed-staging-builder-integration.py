"""Exercise the complete historical Node closure in disposable builder transactions.

Only the isolated fixture review is rebased to the tested source snapshot.
The historical staging/receipt and production draft are never modified.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser()
for name in ('sdk', 'image', 'staging', 'producer-repo', 'review', 'catalogue', 'runtime-directory'):
    parser.add_argument('--' + name, type=Path, required=True)
parser.add_argument('--fixed-review', action='store_true', help='Require exact production review pins; never rebase the review')
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-multi-builder.') as temporary:
    work = Path(temporary)
    repo = work / 'repo'
    for name in ('scripts', 'support', 'platforms'):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns('__pycache__'))
    review = json.loads(args.review.read_text())
    names = sorted(review['packages'])
    for name in names:
        shutil.copytree(source / 'packages' / name, repo / 'packages' / name,
                        ignore=shutil.ignore_patterns('root', '__pycache__'))
    for item in review['changed_inputs']:
        digest = hashlib.sha256((repo / item['path']).read_bytes()).hexdigest()
        if args.fixed_review:
            assert item['consumer_sha256'] == digest, 'fixed consumer input changed'
        else:
            item['consumer_sha256'] = digest
    shared = {}
    paths = list((repo / 'support').rglob('*')) + [p for p in (repo / 'scripts').iterdir() if p.suffix in ('.py', '.sh')]
    for path in sorted(set(paths)):
        if path == repo / 'support/ai-common-library-cohort.json' or path.is_dir() or path.suffix == '.pyc' or '__pycache__' in path.parts:
            continue
        shared[path.relative_to(repo).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    shared_digest = hashlib.sha256(json.dumps(shared, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    if args.fixed_review:
        assert review['consumer_shared_inputs_count'] == len(shared)
        assert review['consumer_shared_inputs_sha256'] == shared_digest, 'fixed shared input snapshot changed'
    else:
        review['consumer_shared_inputs_count'] = len(shared)
        review['consumer_shared_inputs_sha256'] = shared_digest
    pinned = work / 'fixture-review.json'
    if args.fixed_review:
        pinned.write_bytes(args.review.read_bytes())
    else:
        pinned.write_text(json.dumps(review))
    package = repo / 'packages/fixture-uv-client'
    package.mkdir()
    (package / 'package.env').write_text(
        "PACKAGE='fixture-uv-client'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
        "MAINTAINER='Fixture'\nDESCRIPTION='Imported multi-provider consumer'\n"
        "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='r11'\nPACKAGE_KIND='application'\n"
        "PACKAGE_BUILD_DEPENDS='" + ' '.join(names) + "'\nPACKAGE_DEPENDS='libuv (= 1.51.0-1)'\n"
        "SOURCE_LOCK_EXEMPT_REASON='Isolated first-party integration fixture'\n")
    (package / 'client.c').write_text('#include <uv.h>\n#include <stdio.h>\nint main(void){uv_loop_t l;if(uv_loop_init(&l))return 1;if(uv_loop_close(&l))return 2;puts("Imported UV consumer: PASS");return 0;}\n')
    (package / 'build.sh').write_text(
        '#!/usr/bin/env bash\nset -euo pipefail\np=$(cd "$(dirname "$0")" && pwd)\n'
        'source "$p/../../support/source-archive-library.sh"\npayload=$(tdvp_prepare_generated_payload_root "$p")\n'
        'mkdir -p "$payload/usr/bin"\n"$TDVP_SDK_ROOT/bin/riscv64-unknown-linux-gnu-gcc" '
        '-march=rv64imafdc -mabi=lp64d -I"$TDVP_FEED_STAGING_ROOT/usr/include" "$p/client.c" '
        '-L"$TDVP_FEED_STAGING_ROOT/usr/lib" -Wl,-rpath-link,"$TDVP_FEED_STAGING_ROOT/usr/lib" '
        '-luv -o "$payload/usr/bin/fixture-uv-client"\n')
    env = dict(os.environ, TDVP_SDK_ROOT=str(args.sdk.resolve()), TDVP_FEED_BASE_ROOT=str(args.image.resolve()), TDVP_REQUIRE_STAGING_RECEIPT='1')
    exported = work / 'exported'
    first_destination = None
    for iteration in (1, 2):
        output = work / ('feed-' + str(iteration))
        destination = output / 'tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r11/riscv64'
        shutil.copytree(args.catalogue, destination)
        for name in names:
            ipk = name + '_' + review['packages'][name]['consumer_version'] + '_riscv64.ipk'
            shutil.copy2(args.runtime_directory / ipk, destination / ipk)
        owners = args.staging / 'tdvp-runtime-owners.tsv'
        if owners.exists():
            shutil.copy2(owners, destination / '.tdvp-runtime-owners.tsv')
        for name in ('Packages', 'Packages.gz', 'Packages.asc', 'Packages.sig'):
            (destination / name).unlink(missing_ok=True)
        command = ['bash', str(repo / 'scripts/build-all.sh'), '--platform', 'tdvp-k230-r1', '--release', 'r11',
                   '--output', str(output), '--reuse-runtime-catalog', '--offline-source-cache', '--package', 'fixture-uv-client']
        for name in names:
            command += ['--provided-package', name]
        if iteration == 1:
            command += ['--import-reviewed-staging', str(args.staging), '--staging-producer-repo', str(args.producer_repo),
                        '--staging-input-review', str(pinned), '--export-staging', str(exported)]
            first_destination = destination
        else:
            command += ['--import-staging', str(exported)]
        result = subprocess.run(command, env=env, capture_output=True, text=True)
        assert result.returncode == 0, result.stdout[-8000:] + result.stderr[-8000:]
        if iteration == 1:
            origin = json.loads((exported / 'tdvp-historical-development.json').read_text())
            assert origin['audit']['packages'] == review['packages']
            assert origin['producer_receipt_text'].encode() == (args.staging / 'tdvp-build-staging-receipt.json').read_bytes()
            verify = ['python3', str(repo / 'scripts/build-staging-receipt.py'), 'verify', '--repo', str(repo),
                      '--sdk', str(args.sdk), '--staging', str(exported)]
            subprocess.run(verify, check=True)
            origin_path = exported / 'tdvp-historical-development.json'
            original_origin = origin_path.read_bytes()
            tampered = json.loads(original_origin)
            tampered['audit']['packages']['libnode']['consumer_version'] = '22.23.2-999'
            origin_path.write_text(json.dumps(tampered))
            assert subprocess.run(verify, capture_output=True).returncode != 0, 'historical mapping tamper accepted'
            origin_path.write_bytes(original_origin)
            subprocess.run(verify, check=True)
    data = subprocess.check_output(['ar', 'p', str(first_destination / 'fixture-uv-client_1.0-1_riscv64.ipk'), 'data.tar.gz'])
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        member = next(m for m in archive if m.name.lstrip('./') == 'usr/bin/fixture-uv-client')
        consumer = work / 'consumer'
        consumer.write_bytes(archive.extractfile(member).read())
        consumer.chmod(0o755)
    subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(args.image), '-E',
                    'LD_LIBRARY_PATH=' + str(args.staging / 'usr/lib') + ':' + str(args.image / 'usr/lib'), str(consumer)], check=True)
print('Multi-provider builder: PASS exact closure, consumer, original provenance, export and ordinary reuse; empty offline source cache')
