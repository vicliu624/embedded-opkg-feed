# libffi 3.4.6 shared-runtime boundary

`libffi-8` is the sole TDVP feed owner of the public foreign-function
interface ABI:

```
/usr/lib/libffi.so.8 -> libffi.so.8.1.4
```

The package is deliberately a reusable runtime provider rather than an
implementation detail of CPython.  CPython's `_ctypes` extension and any
future FFI consumer must depend on `libffi-8`; they must not ship a private
copy or resolve the SONAME from the base firmware.

The recipe locks Buildroot 2025.02.1's reviewed libffi 3.4.6 archive in
`source.lock`, verifies that artifact through the content-addressed offline
source cache, and materialises only the public `libffi.so*` payload.  It does
not install headers, `libffi.pc`, static archives, or Buildroot staging data
into the feed.  Candidate payload checks require a RISC-V ELF64 shared object,
SONAME `libffi.so.8`, no RPATH/RUNPATH, and no non-platform runtime dependency.

This is candidate-admission evidence only.  A release still needs the normal
matching K230 install, consumer functionality, uninstall, and rollback tests
before signing or promotion.
