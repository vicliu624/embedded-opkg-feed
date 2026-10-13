"""Exercise the production source notice loop without invoking a compiler."""
from pathlib import Path
import os
import re
import subprocess
import tempfile

repo = Path(__file__).resolve().parents[1]
source = (repo / 'support/published-sdk-build.sh').read_text()
loop = re.search(r'^  for license in COPYING .*?^  done$', source, re.M | re.S)
assert loop, 'production notice loop absent'
names = 'COPYING COPYING.txt COPYING.LESSER LICENSE LICENSE.txt LICENCE LICENCE.txt COPYRIGHT NOTICE PATENTS License COPYRIGHT.txt COPYING.0BSD COPYING.GPLv2 COPYING.GPLv3 COPYING.LGPLv2.1 docs/COPYING'.split()
with tempfile.TemporaryDirectory(prefix='tdvp-source-notices-') as temporary:
    work = Path(temporary)
    src = work / 'source'
    install = work / 'install'
    src.mkdir()
    for name in names:
        (src / name).parent.mkdir(parents=True, exist_ok=True)
        (src / name).write_bytes(('Original ' + name + '\r\n').encode())
    (src / 'unrelated.txt').write_text('Do not distribute unrelated source files')
    env = dict(os.environ, source_root=str(src), install_root=str(install), component='fixture')
    subprocess.run(['bash', '-Eeuo', 'pipefail', '-c', loop[0]], env=env, check=True)
    notices = install / 'usr/share/licenses/fixture'
    assert sorted(p.relative_to(notices).as_posix() for p in notices.rglob('*') if p.is_file()) == sorted(names)
    for name in names:
        assert (notices / name).read_bytes() == (src / name).read_bytes(), name
        assert (notices / name).stat().st_mode & 0o777 == 0o644, name
print('Source notice filenames: PASS original bytes, supplementary terms and scoped files')
