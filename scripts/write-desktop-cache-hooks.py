#!/usr/bin/env python3
"""Generate deterministic opkg cache hooks from the actual desktop payload."""
from pathlib import Path
import shlex
import sys


def write_hooks(payload, control):
    icons = payload / "usr/share/icons"
    themes = sorted(path.name for path in icons.iterdir() if path.is_dir() and not path.is_symlink()) if icons.is_dir() else []
    desktop = any((payload / "usr/share/applications").glob("*.desktop"))
    mime = any((payload / "usr/share/mime/packages").glob("*.xml"))
    if not (themes or desktop or mime):
        return
    lines = [
        "#!/bin/sh", "# Generated from package payload; safe to run repeatedly.", "set -eu",
        '# An offline image must refresh caches in its own finalization step.',
        'case "${IPKG_INSTROOT:-${PKG_ROOT:-/}}" in ""|/) ;; *) exit 0 ;; esac',
    ]
    if themes:
        lines += ["if command -v gtk-update-icon-cache >/dev/null 2>&1; then"]
        for theme in themes:
            directory = shlex.quote("/usr/share/icons/" + theme)
            lines += [f"    if [ -f {directory}/index.theme ]; then",
                      f"        gtk-update-icon-cache -f -t {directory}", "    fi"]
        lines += ["else", "    echo 'opkg: gtk-update-icon-cache unavailable; icon cache refresh deferred' >&2", "fi"]
    if desktop:
        lines += ["if command -v update-desktop-database >/dev/null 2>&1 && [ -d /usr/share/applications ]; then",
                  "    update-desktop-database /usr/share/applications", "fi"]
    if mime:
        lines += ["if command -v update-mime-database >/dev/null 2>&1 && [ -d /usr/share/mime ]; then",
                  "    update-mime-database /usr/share/mime", "fi"]
    for name, action in (("postinst", "configure"), ("postrm", "remove")):
        path = control / name
        if path.exists():
            raise ValueError("refusing to overwrite an existing maintainer script: " + str(path))
        content = lines[:3] + [f'case "${{1:-}}" in {action}) ;; *) exit 0 ;; esac'] + lines[3:]
        path.write_text("\n".join(content) + "\n", encoding="utf-8", newline="\n")
        path.chmod(0o755)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: write-desktop-cache-hooks.py <payload> <control-directory>")
    write_hooks(Path(sys.argv[1]), Path(sys.argv[2]))
