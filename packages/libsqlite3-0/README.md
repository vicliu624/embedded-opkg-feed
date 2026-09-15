# SQLite 3.48.0 shared-runtime boundary

`libsqlite3-0` is the sole TDVP feed owner of the public SQLite ABI:

```
/usr/lib/libsqlite3.so.0 -> libsqlite3.so.0.8.6
```

CPython's `_sqlite3` extension and future database clients must depend on this
package. They must not ship a private SQLite library or fall back to a copy in
the base firmware.

The recipe locks Buildroot 2025.02.1's reviewed SQLite 3.48.0 archive in
`source.lock`, uses the verified content-addressed source cache, and extracts
only `libsqlite3.so*`. It excludes the `sqlite3` command, headers, static
archive, pkg-config metadata, and Buildroot staging data. Candidate checks
require RISC-V ELF64, SONAME `libsqlite3.so.0`, no RPATH/RUNPATH, and exact
runtime providers.

Candidate admission is not release promotion: matching K230 install, database
consumer functionality, uninstall, and rollback tests remain required before
signing or publication.
