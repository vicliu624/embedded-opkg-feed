#!/usr/bin/env python3
"""Reject lost supported package names across every archived catalogue."""
import argparse
from pathlib import Path
import re

RETIRED = {
    'libdisplay': 'CPU0 camera HAL retired; CPU1 owns the camera/AI subsystem',
    'libv4l2-drm': 'CPU0 camera HAL retired; CPU1 owns the camera/AI subsystem',
    'libv4l2-drm++': 'CPU0 camera HAL retired; CPU1 owns the camera/AI subsystem',
    'libvvcam': 'CPU0 camera HAL retired; CPU1 owns the camera/AI subsystem',
    'tdvp-hello': 'r1/r2 packaging fixture; excluded from production catalogues',
}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo-root', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
args = parser.parse_args()
history_root = args.repo_root / 'site/feed'
indices = sorted(history_root.rglob('Packages'))
if not indices:
    raise SystemExit('historical continuity: no archived indices found')
historical = set()
for index in indices:
    historical.update(re.findall(r'^Package: ([a-z0-9][a-z0-9+.-]*)$', index.read_text(), re.M))
candidate = set(re.findall(r'^Package: ([a-z0-9][a-z0-9+.-]*)$',
    (args.candidate / 'Packages').read_text(), re.M))
if not historical or not candidate:
    raise SystemExit('historical continuity: empty package catalogue')
missing = historical - candidate - RETIRED.keys()
forbidden = candidate & RETIRED.keys()
if missing:
    raise SystemExit('historical continuity: missing supported names: ' + ', '.join(sorted(missing)))
if forbidden:
    raise SystemExit('historical continuity: retired names reintroduced: ' + ', '.join(sorted(forbidden)))
print(f'historical continuity: PASS {len(historical)} historical names, {len(candidate)} candidate names')
for package in sorted(historical & RETIRED.keys()):
    print('retired: ' + package + ': ' + RETIRED[package])
