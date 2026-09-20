#!/usr/bin/env python3
"""Validate the published TDVP SDK before any feed recipe starts building."""

import argparse
import json
from pathlib import Path
import shutil
import sys


LEGACY_KIND = "tdvp-cpu0-application-sdk"
PACKAGE_KIND = "tdvp-cpu0-sdk"
REQUIRED_DEVELOPMENT = {
    "headers": (
        "usr/include/curses.h",
        "usr/include/curl/curl.h",
        "usr/include/glib-2.0/glib.h",
        "usr/include/gtk-3.0/gtk/gtk.h",
        "usr/include/openssl/ssl.h",
        "usr/include/wayland-client.h",
        "usr/include/zlib.h",
    ),
    "pkgconfig": (
        "usr/lib/pkgconfig/ncursesw.pc",
        "usr/lib/pkgconfig/libcurl.pc",
        "usr/lib/pkgconfig/glib-2.0.pc",
        "usr/lib/pkgconfig/gtk+-3.0.pc",
        "usr/lib/pkgconfig/openssl.pc",
        "usr/lib/pkgconfig/wayland-client.pc",
        "usr/lib/pkgconfig/zlib.pc",
    ),
    "linker_libraries": (
        "usr/lib/libncursesw.so",
        "usr/lib/libcurl.so",
        "usr/lib/libglib-2.0.so",
        "usr/lib/libgtk-3.so",
        "usr/lib/libssl.so",
        "usr/lib/libwayland-client.so",
        "usr/lib/libz.so",
    ),
}


def require_development_files(sdk, manifest):
    inventory = manifest.get("development")
    for category, paths in REQUIRED_DEVELOPMENT.items():
        for path in paths:
            if not (sdk / "sysroot" / path).is_file():
                raise ValueError("package SDK lacks required {} path: {}".format(category, path))
            if inventory is not None and path not in inventory.get(category, []):
                raise ValueError("package SDK development inventory omits {}".format(path))


def verify(sdk, check_host_tools):
    manifest_path = sdk / "tdvp-sdk-manifest.json"
    manifest = json.loads(manifest_path.read_text())
    schema = manifest.get("schema")
    if schema == 2:
        if manifest.get("kind") != PACKAGE_KIND or manifest.get("capabilities", {}).get("package_build") is not True:
            raise ValueError("published SDK does not authorize package builds")
        if check_host_tools:
            contract = manifest.get("host_environment", {})
            missing = [tool for tool in contract.get("required_commands", []) if shutil.which(tool) is None]
            if missing:
                raise ValueError("package builder host lacks required tools: " + ", ".join(missing))
    elif schema == 1 and manifest.get("kind") == LEGACY_KIND:
        if check_host_tools:
            print("package SDK preflight: legacy schema 1 has no host-tool contract", file=sys.stderr)
    else:
        raise ValueError("unsupported TDVP SDK manifest")
    require_development_files(sdk, manifest)
    print("package SDK preflight: PASS schema {} {}".format(schema, "with host tools" if check_host_tools and schema == 2 else "development closure"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sdk", type=Path)
    parser.add_argument("--host-tools", action="store_true")
    args = parser.parse_args()
    try:
        verify(args.sdk.resolve(), args.host_tools)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        parser.exit(1, "package SDK preflight failed: {}\n".format(error))


if __name__ == "__main__":
    main()
