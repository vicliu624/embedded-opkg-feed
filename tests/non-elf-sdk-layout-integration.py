"""Run non-ELF builder fixtures against SDK layouts with/without sibling target."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('sdk', type=Path)
args = parser.parse_args()
sdk = args.sdk.resolve(strict=True)
repo = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='tdvp-non-elf-layouts-') as directory:
    root = Path(directory)
    for layout in ('without-target', 'with-target'):
        parent = root / layout
        view = parent / 'sdk'
        view.mkdir(parents=True)
        # The top-level directory stays real so argument resolve() preserves
        # the layout. Child links reuse unchanged SDK bytes and tools.
        for item in sdk.iterdir():
            (view / item.name).symlink_to(item, target_is_directory=item.is_dir())
        target = parent / 'target'
        if layout == 'with-target':
            (target / 'usr/lib').mkdir(parents=True)
            (target / 'usr/lib/layout-sentinel').write_text('not a platform runtime\n')
        environment = dict(os.environ)
        # Also prove a caller's base root cannot leak into either fixture.
        environment['TDVP_FEED_BASE_ROOT'] = str(target)
        for test in ('build-staging-receipt-integration', 'split-provider-builder-integration'):
            result = subprocess.run(['python3', str(repo / 'tests' / (test + '.py')), str(view)],
                                    env=environment, capture_output=True, text=True, timeout=120)
            assert result.returncode == 0, (layout, test, result.stdout + result.stderr)
            print(layout + ': ' + result.stdout.strip())
print('Non-ELF SDK layout integration: PASS both layouts and inherited base-root isolation')
