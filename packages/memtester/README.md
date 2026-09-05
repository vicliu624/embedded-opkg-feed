# memtester isolated memory-diagnostic cohort

`memtester` builds memtester 4.5.1 only from the archive recorded in
`source.lock`, using Buildroot 2025.02.1 in a private GitHub Actions
transaction. It owns a source-built RISC-V ELF only below
`/usr/libexec/tdvp-memtester/`; its single public command is the explicit,
collision-free `/usr/bin/tdvp-memtester` wrapper. It never owns an unprefixed
command, `/bin/*`, `/sbin/*`, a firmware file, a copied target-root library,
or a Debian binary.

Buildroot lists no runtime package dependency for this one-command suite. The
candidate job still proves its actual RISC-V runtime closure; a newly discovered
shared library or base-overlay path fails the batch instead of becoming an
implicit firmware dependency.

memtester allocates and writes the memory region selected by its device user;
the optional physical-address mode has still higher operational risk. CI only
retrieves locked source, cross-compiles, packages, and audits ABI/path closure;
it never executes the program. Any device validation must use a non-production
test unit, a conservative explicitly selected memory budget, recorded
install/uninstall/rollback, and only then can a signed release be considered.
