# GNU mtools 4.0.47 command boundary

`mtools` owns a locked-source RISC-V multi-call ELF and its selected relative
applet symlinks only below `/usr/libexec/tdvp-mtools/`. Public commands are
explicit `/usr/bin/tdvp-mtools-*` wrappers, including `tdvp-mtools-mdir`,
`tdvp-mtools-mcopy`, `tdvp-mtools-mformat`, and `tdvp-mtools-mlabel`. It never
owns `/bin/*`, an unprefixed `/usr/bin/*`, a firmware file, a copied target-root
library, or a Debian binary.

The private Buildroot transaction uses the source.lock-approved GNU mtools
archive and the separately locked, host-only lzip 1.25 archive required to
unpack it; host lzip never enters the target IPK. It restores the platform
Kconfig byte-for-byte. GitHub Actions must validate the lock, RISC-V ELF
machine, no RPATH/RUNPATH, IPK runtime closure, and base-overlay policy before
uploading an unsigned candidate.

Candidate admission is not release promotion. Device validation must still
record a non-destructive directory listing/copy path and explicit, carefully
selected format/label checks, then uninstall and rollback before signing or
publishing is authorized.
