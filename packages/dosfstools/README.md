# dosfstools 4.2 command boundary

`dosfstools` owns three locked-source RISC-V ELF files only below
`/usr/libexec/tdvp-dosfstools/`: `mkfs.fat`, `fsck.fat`, and `fatlabel`. Its
public commands are explicit `tdvp-dosfstools-*` wrappers. It never owns
`/sbin/*`, an unprefixed `/usr/bin/*`, a firmware file, a copied target-root
library, or a Debian binary.

The private Buildroot transaction restores the platform Kconfig byte-for-byte.
GitHub Actions must validate the source lock, RISC-V ELF machine, no
RPATH/RUNPATH, IPK runtime closure, and base-overlay policy before uploading an
unsigned candidate. CI does not execute formatting or repair operations.

Candidate admission is not release promotion. Device validation must use an
explicitly selected non-production FAT medium, record create/check/label
behavior, then uninstall and rollback before signing or publishing is
authorized.
