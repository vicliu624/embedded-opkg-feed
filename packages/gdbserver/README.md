# gdbserver remote-debug candidate

`gdbserver` uses the GNU GDB 15.1 source archive recorded in `source.lock` and
Buildroot 2025.02.1 only inside a private GitHub Actions transaction. It enables
the target `gdbserver` stub, not a full on-device debugger: target GDB, TUI,
Python, ncurses, zlib, GMP, and MPFR remain outside this candidate.

The temporary Buildroot install may call the source command `gdbserver`, but
the IPK owns the source-built RISC-V ELF only at
`/usr/libexec/tdvp-gdbserver/gdbserver` and exposes exactly
`/usr/bin/tdvp-gdbserver`. It never replaces a firmware command, copies a
debug binary from the SDK, or mutates the restored SDK host `debug-root`.

CI builds, extracts, and audits the stub but never listens on a TCP port or
attaches to a process. Device validation must use a controlled development
target, an explicit endpoint, an install/debug/uninstall/rollback record, and
only then can a signed release be considered.
