"""Reconstruct pinned r12 opkg sources and bound the retained prototype diff."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

parser = argparse.ArgumentParser()
for name in ('archive', 'image-patches', 'batch-patch', 'prototype'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
source = args.archive.read_bytes()
assert hashlib.sha256(source).hexdigest() == 'd973fd0f1568f58f87d6aecd9aa95e3e1f60214a45cee26704bf8fe757c54567'
pins = {
    '0001-internal-solver-reuse-installed-alternative.patch': '82b6c03b0b950dded786a4290ba662e776965fc5323db256792d73f229c71b23',
    '0002-reject-held-candidates-with-unmet-constraints.patch': '46542a73bb3e855fc65e6191b6b6ed3035bd84efd56567f1a982cb58f650c81a',
    '0003-preserve-file-list-when-owner-is-unchanged.patch': 'aee8567ced44e7135c61e59d00bf11b57242197fab4c270369955a51911633e9',
    '0004-preserve-essential-held-file-ownership.patch': '63370897a4d2d5baf2d3e7b4f797173e7c488ebe7658754c4a2f00f0aa66f499',
}
batch = args.batch_patch.read_bytes()
assert hashlib.sha256(batch).hexdigest() == '7c2501e9ba61147bc6a2252d9df405b403087a09fd6b283d34825cecc6534f89'
for name, digest in pins.items():
    assert hashlib.sha256((args.image_patches / name).read_bytes()).hexdigest() == digest
with tempfile.TemporaryDirectory(prefix='tdvp-opkg-source-audit.') as directory:
    work = Path(directory)
    with tarfile.open(fileobj=io.BytesIO(source), mode='r:gz') as archive:
        archive.extractall(work, filter='data')
    baseline = work / 'opkg-0.7.0'
    for name in pins:
        subprocess.run(['patch', '--directory=' + str(baseline), '-p1', '--fuzz=0', '--forward'],
                       input=(args.image_patches / name).read_bytes(), check=True, capture_output=True)
    names = {path.relative_to(baseline).as_posix() for path in baseline.rglob('*')
             if path.is_file() and path.suffix in ('.c', '.h', '.am', '.ac')}
    prototype_names = {path.relative_to(args.prototype).as_posix() for path in args.prototype.rglob('*')
                       if path.is_file() and path.suffix in ('.c', '.h', '.am', '.ac')}
    assert names == prototype_names, 'unreviewed source file set'
    changed = sorted(name for name in names if (baseline / name).read_bytes() != (args.prototype / name).read_bytes())
    upgrade = 'libopkg/solvers/internal/opkg_upgrade_internal.c'
    caller = 'libopkg/solvers/internal/opkg_action.c'
    assert changed == sorted((upgrade, caller))
    subprocess.run(['patch', '--directory=' + str(baseline), '-p1', '--fuzz=0', '--forward'],
                   input=batch, check=True, capture_output=True)
    upgraded = (baseline / upgrade).read_text()
    snapshot = '        old_wants[i] = pkg->state_want;\n        if (!(pkg->state_flag & (SF_HOLD | SF_REPLACE)))'
    separated = ('        old_wants[i] = pkg->state_want;\n    }\n'
                 '    for (i = 0; i < pkgs_to_upgrade->len; i++) {\n'
                 '        pkg = pkgs_to_upgrade->pkgs[i];\n'
                 '        if (!(pkg->state_flag & (SF_HOLD | SF_REPLACE)))')
    assert upgraded.count(snapshot) == 1
    upgraded = upgraded.replace(snapshot, separated)
    insertion = '        pkg_vec_insert(upgrade_pkgs, new);'
    assert upgraded.count(insertion) == 1
    upgraded = upgraded.replace(insertion, '        if (!pkg_vec_contains(upgrade_pkgs, new))\n    ' + insertion)
    assert upgraded.encode() == (args.prototype / upgrade).read_bytes(), 'unreviewed batch refinements'
    text = (baseline / caller).read_text()
    start = text.index('int opkg_solver_upgrade(')
    end = text.index('int opkg_solver_list_upgradable(', start)
    body = text[start:end]
    assert body.count('    int r;\n') == 1 and body.count('if (opkg_config->combine)') == 4
    expected = body.replace('    int r;\n', '    int r;\n    int combine = opkg_config->combine || num_pkgs != 1;\n')
    expected = expected.replace('if (opkg_config->combine)', 'if (combine)')
    assert (text[:start] + expected + text[end:]).encode() == (args.prototype / caller).read_bytes(), 'unreviewed caller changes'
print(json.dumps({'schema': 1, 'kind': 'tdvp-opkg-prototype-source-review',
    'baseline_release_commit': '0701ec63edf8f4811f4d8003b30b177167870163',
    'scope': 'C/header/autotools source bytes; not compiler configuration or binary reproducibility',
    'source_files_checked': len(names), 'changed_files': changed,
    'source_archive_sha256': hashlib.sha256(source).hexdigest(), 'baseline_patch_sha256': pins,
    'batch_patch_sha256': hashlib.sha256(batch).hexdigest(), 'image_modified': False,
    'reviewed_refinements': ['snapshot all old wants before marking a duplicate batch',
                            'deduplicate selected upgrade packages', 'default multi/all requests use combined upgrade'],
    'integration_authorized': False}, sort_keys=True, indent=2))
