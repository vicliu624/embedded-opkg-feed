# GNU coreutils 9.5 command boundary

`coreutils` owns exactly one locked-source RISC-V multi-call ELF at
`/usr/libexec/tdvp-coreutils/coreutils`. Private relative symlinks preserve
each GNU applet's required `argv[0]`; its public commands are only explicit
`/usr/bin/tdvp-coreutils-<command>` wrappers, including `tdvp-coreutils-ls`,
`tdvp-coreutils-cp`, and `tdvp-coreutils-chroot`. It never owns `/bin/*`, an
unprefixed `/usr/bin/*`, a firmware file, a copied target-root library, or a
Debian binary.

The private Buildroot transaction disables ACL, attr, libcap, libselinux,
OpenSSL, and NLS branches. This keeps the package's runtime closure limited to
the reviewed K230 ABI seeds unless a future, independently source-built
provider undergoes a separate admission. GitHub Actions must validate the
source lock, RISC-V ELF machine, no RPATH/RUNPATH, IPK runtime closure, and
base-overlay policy before it uploads an unsigned candidate.

Candidate admission is not release promotion. K230 device validation still
needs representative wrapper execution, removal, and rollback before signing
or publishing is authorized.
