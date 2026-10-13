"""Exercise reviewed import with real DB development/runtime and a target consumer.

The review is rebased only inside this disposable fixture to cover its exact
consumer snapshot; production review and producer receipt remain unchanged.
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
for name in ('sdk', 'image', 'staging', 'producer-repo', 'review', 'catalogue', 'runtime-ipk'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-reviewed-builder.') as temporary:
    work = Path(temporary)
    repo = work / 'repo'
    for name in ('scripts', 'support', 'platforms'):
        shutil.copytree(source / name, repo / name, ignore=shutil.ignore_patterns('__pycache__'))
    shutil.copytree(source / 'packages/libdb', repo / 'packages/libdb', ignore=shutil.ignore_patterns('root'))
    review = json.loads(args.review.read_text())
    for item in review['changed_inputs']:
        item['consumer_sha256'] = hashlib.sha256((repo / item['path']).read_bytes()).hexdigest()
    inputs = {}
    paths = list((repo / 'support').rglob('*')) + [p for p in (repo / 'scripts').iterdir() if p.suffix in ('.py', '.sh')]
    for path in sorted(set(paths)):
        if path == repo / 'support/ai-common-library-cohort.json' or path.is_dir() or path.suffix == '.pyc' or '__pycache__' in path.parts:
            continue
        inputs[path.relative_to(repo).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    review['consumer_shared_inputs_count'] = len(inputs)
    review['consumer_shared_inputs_sha256'] = hashlib.sha256(json.dumps(inputs, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    pinned = work / 'fixture-review.json'
    pinned.write_text(json.dumps(review))
    package = repo / 'packages/fixture-db-client'
    package.mkdir()
    (package / 'package.env').write_text(
        "PACKAGE='fixture-db-client'\nVERSION='1.0-1'\nPACKAGE_ARCH='riscv64'\n"
        "MAINTAINER='Fixture'\nDESCRIPTION='Real imported DB consumer'\n"
        "SUPPORTED_PLATFORMS='tdvp-k230-r1'\nPACKAGE_RELEASES='r11'\n"
        "PACKAGE_KIND='application'\nPACKAGE_BUILD_DEPENDS='libdb'\nPACKAGE_DEPENDS='libdb (= 18.1.40-1)'\n"
        "SOURCE_LOCK_EXEMPT_REASON='Isolated first-party integration fixture'\n")
    (package / 'client.c').write_text(
        '#include <db.h>\n#include <string.h>\n#include <stdio.h>\n'
        'int main(void){DB *db; if(db_create(&db,0,0))return 1;'
        'if(db->open(db,0,0,0,DB_BTREE,DB_CREATE,0600))return 2;'
        'DBT k={0},v={0},r={0}; char key[]="tdvp",value[]="verified";'
        'k.data=key;k.size=sizeof(key);v.data=value;v.size=sizeof(value);'
        'if(db->put(db,0,&k,&v,0)||db->get(db,0,&k,&r,0))return 3;'
        'if(r.size!=sizeof(value)||memcmp(r.data,value,sizeof(value)))return 4;'
        'if(db->close(db,0))return 5;puts("Reviewed DB consumer: PASS");return 0;}\n')
    (package / 'build.sh').write_text(
        '#!/usr/bin/env bash\nset -euo pipefail\n'
        'p=$(cd "$(dirname "$0")" && pwd)\nsource "$p/../../support/source-archive-library.sh"\n'
        'payload=$(tdvp_prepare_generated_payload_root "$p")\nmkdir -p "$payload/usr/bin"\n'
        '"$TDVP_SDK_ROOT/bin/riscv64-unknown-linux-gnu-gcc" -march=rv64imafdc -mabi=lp64d '
        '-I"$TDVP_FEED_STAGING_ROOT/usr/include" "$p/client.c" -L"$TDVP_FEED_STAGING_ROOT/usr/lib" '
        '-Wl,-rpath-link,"$TDVP_FEED_STAGING_ROOT/usr/lib" -ldb -o "$payload/usr/bin/fixture-db-client"\n')
    env = dict(os.environ, TDVP_SDK_ROOT=str(args.sdk.resolve()), TDVP_FEED_BASE_ROOT=str(args.image.resolve()), TDVP_REQUIRE_STAGING_RECEIPT='1')
    output = work / 'feed'
    destination = output / 'tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r11/riscv64'
    shutil.copytree(args.catalogue, destination)
    shutil.copy2(args.runtime_ipk, destination / args.runtime_ipk.name)
    shutil.copy2(args.staging / 'tdvp-runtime-owners.tsv', destination / '.tdvp-runtime-owners.tsv')
    for name in ('Packages', 'Packages.gz', 'Packages.asc', 'Packages.sig'):
        index = destination / name
        if index.exists():
            index.unlink()
    exported = work / 'exported'
    command = ['bash', str(repo / 'scripts/build-all.sh'), '--platform', 'tdvp-k230-r1', '--release', 'r11',
               '--output', str(output), '--reuse-runtime-catalog', '--offline-source-cache',
               '--import-reviewed-staging', str(args.staging), '--staging-producer-repo', str(args.producer_repo),
               '--staging-input-review', str(pinned), '--provided-package', 'libdb', '--package', 'fixture-db-client',
               '--export-staging', str(exported)]
    # Empty offline source cache prevents rebuilding the locked libdb source.
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout[-6000:] + result.stderr[-6000:]
    origin = exported / 'tdvp-historical-development.json'
    assert json.loads(origin.read_text())['audit']['package'] == 'libdb'
    verify = ['python3', str(repo / 'scripts/build-staging-receipt.py'), 'verify', '--repo', str(repo),
              '--sdk', str(args.sdk), '--staging', str(exported)]
    subprocess.run(verify, check=True)
    original_origin = origin.read_bytes()
    tampered = json.loads(original_origin)
    tampered['producer_receipt_text'] += 'tampered'
    origin.write_text(json.dumps(tampered))
    assert subprocess.run(verify, capture_output=True).returncode != 0, 'historical origin tamper accepted'
    origin.write_bytes(original_origin)
    subprocess.run(verify, check=True)
    second_output = work / 'second-feed'
    second_destination = second_output / destination.relative_to(output)
    shutil.copytree(args.catalogue, second_destination)
    shutil.copy2(args.runtime_ipk, second_destination / args.runtime_ipk.name)
    shutil.copy2(args.staging / 'tdvp-runtime-owners.tsv', second_destination / '.tdvp-runtime-owners.tsv')
    for name in ('Packages', 'Packages.gz', 'Packages.asc', 'Packages.sig'):
        path = second_destination / name
        if path.exists():
            path.unlink()
    ordinary = ['bash', str(repo / 'scripts/build-all.sh'), '--platform', 'tdvp-k230-r1', '--release', 'r11',
                '--output', str(second_output), '--reuse-runtime-catalog', '--offline-source-cache',
                '--import-staging', str(exported), '--provided-package', 'libdb', '--package', 'fixture-db-client']
    result = subprocess.run(ordinary, env=env, capture_output=True, text=True)
    assert result.returncode == 0, result.stdout[-6000:] + result.stderr[-6000:]
    ipk = destination / 'fixture-db-client_1.0-1_riscv64.ipk'
    data = subprocess.check_output(['ar', 'p', str(ipk), 'data.tar.gz'])
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as archive:
        member = next(m for m in archive if m.name.lstrip('./') == 'usr/bin/fixture-db-client')
        consumer = work / 'consumer'
        consumer.write_bytes(archive.extractfile(member).read())
        consumer.chmod(0o755)
    subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(args.image),
                    '-E', 'LD_LIBRARY_PATH=' + str(args.staging / 'usr/lib') + ':' + str(args.image / 'usr/lib'),
                    str(consumer)], check=True)
print('Reviewed staging builder: PASS consumer, origin/export, normal receipt reuse and tamper rejection; provider not rebuilt')
