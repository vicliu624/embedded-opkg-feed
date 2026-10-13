"""Preserve the finite numeric decoder limit in the libzip recipe."""
from pathlib import Path
import re

repo = Path(__file__).resolve().parents[1]
hook = (repo / "packages/libzip/build.sh").read_text()
values = re.findall(r"-DLIMIT_LZMA_WINDOW=([^\s]+)", hook)
assert values == ["67108864"], values
assert 524288 <= int(values[0]) <= 4294967295
assert "-DENABLE_LZMA=OFF" not in hook
metadata = (repo / "packages/libzip/package.env").read_text()
assert "PACKAGE_BUILD_DEPENDS='liblzma'" in metadata
assert "VERSION='1.12-2'" in metadata
print("libzip LZMA policy: PASS finite numeric 64 MiB decoder limit, LZMA retained")
