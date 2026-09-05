# i2c-tools hardware-inspection candidate

`i2c-tools` uses the kernel.org 4.4 archive recorded in `source.lock` and
Buildroot 2025.02.1 only in a private GitHub Actions transaction. It disables
the optional Python `py-smbus` branch and forces the five command ELF files to
link the private static `libi2c.a`; neither `libi2c.so` nor `libi2c.a` is part
of this IPK.

The IPK owns only these source-built executables below
`/usr/libexec/tdvp-i2c-tools/`: `i2cdetect`, `i2cdump`, `i2cset`, `i2cget`, and
`i2ctransfer`. Its only public commands are `tdvp-i2c-detect`,
`tdvp-i2c-dump`, `tdvp-i2c-set`, `tdvp-i2c-get`, and `tdvp-i2c-transfer`; it
does not replace firmware paths.

CI builds and audits the tools but does not invoke them, enumerate adapters,
read EEPROMs, probe addresses, or write registers. Device work requires an
explicit controlled bus, a documented non-destructive command, and an
install/uninstall/rollback record before any signed release is considered.
