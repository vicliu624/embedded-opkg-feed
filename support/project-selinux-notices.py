"""Project source component notices before compilation generates extra files."""
from pathlib import Path
import hashlib
import re
import sys

root = Path(sys.argv[1]).resolve(strict=True)
package = sys.argv[2]
assert package in ('libsepol', 'libselinux')
destination = root / 'TDVP-COPYRIGHT-NOTICE'
assert not destination.exists() and not destination.is_symlink()
license_text = (root / 'LICENSE').read_text()
if package == 'libselinux':
    assert 'public domain software, i.e. not copyrighted' in license_text
records = []
notice_count = 0
for directory in ('src', 'include', 'cil/src', 'cil/include'):
    for path in sorted((root / directory).rglob('*')):
        if path.suffix not in ('.c', '.h', '.l'):
            continue
        assert path.is_file() and not path.is_symlink() and path.resolve().is_relative_to(root)
        data = path.read_bytes()
        text = data.decode('utf-8')
        blocks = [m.group() for m in re.finditer(r'/\*.*?\*/|//[^\n]*', text, re.S)
                  if re.search(r'copyright|SPDX-License-Identifier|redistribution|license|public domain', m.group(), re.I)]
        notice_count += len(blocks)
        records.append(path.relative_to(root).as_posix() + '\nSHA256: ' + hashlib.sha256(data).hexdigest()
                       + '\n' + ('\n'.join(blocks) if blocks else 'No matching component notice; consult the locked root LICENSE.'))
assert records
if package == 'libsepol':
    assert notice_count > 0 and any('Tresys' in record and 'Redistribution' in record for record in records)
with destination.open('x', encoding='utf-8', newline='\n') as output:
    output.write('Locked source component inventory and verbatim notice comments. Root LICENSE is delivered separately.\n\n')
    output.write('\n\n'.join(records) + '\n')
print('SELinux component notice projection: PASS', package, len(records), 'source files,', notice_count, 'notice blocks')
