"""Exercise SELinux component notice projection and fail-closed boundaries."""
import hashlib
from pathlib import Path
import subprocess
import sys
import tempfile

repo = Path(__file__).resolve().parents[1]
projector = repo / 'support/project-selinux-notices.py'
with tempfile.TemporaryDirectory(prefix='tdvp-selinux-notices-') as directory:
    work = Path(directory)
    for case in ('public-domain', 'bsd-cil', 'foreign-license', 'missing-bsd', 'source-symlink', 'existing-output'):
        root = work / case
        (root / 'src').mkdir(parents=True)
        sepol = case in ('bsd-cil', 'missing-bsd')
        package = 'libsepol' if sepol else 'libselinux'
        (root / 'LICENSE').write_text('LGPL 2.1' if sepol or case == 'foreign-license' else 'public domain software, i.e. not copyrighted')
        content = '/* Copyright Tresys. Redistribution permitted. */\nint fixture;\n' if case == 'bsd-cil' else '/* interface documentation */\nint fixture;\n'
        source = root / 'src/fixture.c'
        if case == 'source-symlink':
            outside = work / 'outside.c'
            outside.write_text(content)
            source.symlink_to(outside)
        else:
            source.write_text(content)
        output = root / 'TDVP-COPYRIGHT-NOTICE'
        if case == 'existing-output':
            output.write_text('preserve existing output')
        result = subprocess.run([sys.executable, str(projector), str(root), package], capture_output=True, text=True)
        assert (result.returncode == 0) == (case in ('public-domain', 'bsd-cil')), result.stdout + result.stderr
        if result.returncode == 0:
            projected = output.read_text()
            assert hashlib.sha256(source.read_bytes()).hexdigest() in projected
            assert 'int fixture;' not in projected
            if case == 'bsd-cil':
                assert 'Copyright Tresys. Redistribution permitted.' in projected
        elif case == 'existing-output':
            assert output.read_text() == 'preserve existing output'
print('SELinux notice projection: PASS public domain, BSD retention, source hashes, no code body, rejection and non-overwrite')
