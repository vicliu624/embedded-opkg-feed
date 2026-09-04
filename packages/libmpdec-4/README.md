# mpdecimal 4.0.0 shared-runtime boundary

`libmpdec-4` is the sole TDVP feed owner of the public decimal arithmetic ABI:

```
/usr/lib/libmpdec.so.4 -> libmpdec.so.4.0.0
```

CPython's `_decimal` extension, when built with the reviewed system mpdecimal
option, must depend on this package. It must not embed another libmpdec copy or
resolve it from base firmware.

The recipe locks Buildroot 2025.02.1's reviewed mpdecimal 4.0.0 archive in
`source.lock`, verifies it in the content-addressed source cache, and extracts
only `libmpdec.so*`. The separate C++ ABI (`libmpdec++.so.4`), headers,
pkg-config data, documentation, and staging files are not feed payload. The
candidate checks require RISC-V ELF64, SONAME `libmpdec.so.4`, no
RPATH/RUNPATH, and no non-platform runtime dependency.

This establishes candidate-admission evidence only. It still requires matching
K230 install, CPython decimal functionality, uninstall, and rollback tests
before signing or release promotion.
