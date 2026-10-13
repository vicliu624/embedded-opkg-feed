#!/usr/bin/env python3
"""Validate install links and relocate internal absolute targets before copying."""
import os
import sys
from pathlib import Path

root_arg = Path(sys.argv[1])
if root_arg.is_symlink() or not root_arg.is_dir():
    raise SystemExit("install link root must be an ordinary directory")
root = root_arg.resolve(strict=True)
changes = []
for path in sorted(root.rglob("*")):
    if not path.is_symlink():
        continue
    target = os.readlink(path)
    try:
        resolved = path.resolve(strict=True)
    except (OSError, RuntimeError) as error:
        raise SystemExit(f"invalid install link: {path} -> {target}: {error}")
    if not resolved.is_relative_to(root):
        raise SystemExit(f"install link escapes root: {path} -> {target}")
    if os.path.isabs(target):
        # Preserve the immediate link target, including legitimate link chains.
        immediate = Path(os.path.normpath(target))
        if not immediate.is_relative_to(root):
            raise SystemExit(f"absolute install link target escapes root: {path} -> {target}")
        changes.append((path, os.path.relpath(immediate, path.parent)))

# Validate the whole tree before modifying any link.
for path, target in changes:
    path.unlink()
    path.symlink_to(target)
print(f"install links verified: {len(changes)} internal absolute links relocated")
