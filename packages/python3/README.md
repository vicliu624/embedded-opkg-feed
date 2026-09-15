# CPython 3.13 direct-source split

`libpython3.13`, `python3-runtime`, and `python3` are one immutable CPython
3.13.3 release archive built once with the matching K230 SDK/sysroot, then
divided by ownership:

| IPK | Owns | Does not own |
| --- | --- | --- |
| `libpython3.13` | `/usr/lib/libpython3.13.so*` | the interpreter and standard library |
| `python3-runtime` | `/usr/lib/python3.13`, including admitted native extension modules | `libpython3.13.so*` and command frontends |
| `python3` | `/usr/bin/python`, `/usr/bin/python3`, and `/usr/bin/python3.13` | the shared ABI and standard library |

The first package performs the source build in a private temporary directory
from the artifact verified by its `source.lock` and the content-addressed TDVP
source cache. It uses Buildroot only to identify the pinned 2025.02.1 SDK and
sysroot. It never enables `BR2_PACKAGE_PYTHON3`, never imports a Buildroot
target-root closure, and never packages a Debian binary. The verified private
stage is reused only while the same feed build creates the other two payloads.

The standard runtime deliberately enables and checks `_ssl`, `_hashlib`,
`_ctypes`, `_decimal`, `_sqlite3`, `_bz2`, `_lzma`, `_curses`, `readline`,
`pyexpat`, `_elementtree`, `zlib`, and `binascii`. Their non-platform SONAMEs
are provided by separately admitted IPKs: OpenSSL, libffi, mpdecimal, SQLite,
bzip2, xz, zlib, ncursesw, readline, and Expat. `pyexpat` must dynamically need
`libexpat.so.1`; `_elementtree` uses CPython's documented pyexpat C-API hook,
so it does not need to carry a second direct Expat link.

The recipe excludes private Expat copies, static/development metadata, generic
`libpython3.so`, IDLE, pydoc, tkinter, turtle demos, ensurepip, manuals, and
the Python build configuration directory. It also forces `_curses_panel` off:
that extension would require `libpanelw.so.6`, for which this feed has no
admitted runtime provider. Every published target ELF is checked as RISC-V
ELF64 and rejected if it retains an RPATH/RUNPATH.

The three IPKs are a source-lock candidate, not a released interpreter by
themselves. Before release, run the source-lock/policy checks, build candidate
IPKs from a fresh cache-backed stage, audit their dependency closure, and run
the K230 install, core-function, uninstall, and rollback tests described in
[`docs/UPSTREAM_SOURCES.md`](../../docs/UPSTREAM_SOURCES.md).
