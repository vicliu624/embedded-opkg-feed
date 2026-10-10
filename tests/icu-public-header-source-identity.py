"""Compare cached ICU public headers with the locked release source."""
import argparse
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('icu_source', type=Path)
parser.add_argument('cached_include', type=Path)
args = parser.parse_args()
source = args.icu_source.resolve(strict=True)
cached = args.cached_include.resolve(strict=True)
expected = {}
for component in ('common', 'i18n', 'io'):
    directory = source / 'source' / component / 'unicode'
    for header in directory.glob('*.h'):
        assert header.is_file() and not header.is_symlink()
        if header.name in expected:
            assert expected[header.name] == header.read_bytes(), header.name
        expected[header.name] = header.read_bytes()
checked = set()
for header in cached.glob('*.h'):
    assert header.is_file() and not header.is_symlink()
    assert header.name in expected, ('no locked source origin', header.name)
    assert header.read_bytes() == expected[header.name], header.name
    checked.add(header.name)
assert 'uvernum.h' in checked and 'utypes.h' in checked and len(checked) > 100
print('ICU public header source identity: PASS', len(checked), 'cached headers match locked release bytes')
