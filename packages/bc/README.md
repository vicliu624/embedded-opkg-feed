# GNU bc 1.07.1 command boundary

`bc` owns one source-built GNU bc RISC-V ELF under
`/usr/libexec/tdvp-bc/bc` and the explicit `/usr/bin/tdvp-bc` wrapper. It
does not own `/usr/bin/bc`, `dc`, a shared library, a parser generator, a
firmware file, or a copied calculator/database payload.

The recipe locks the GNU bc archive plus the Buildroot-required host-flex and
host-m4 archives. Those two tools are host-only Buildroot build inputs and are
never included in the target IPK. A GitHub Actions batch must validate their
SHA-256 values before the private offline Buildroot transaction; the emitted
ELF must be RISC-V, free of RPATH/RUNPATH, runtime-closed, and allowed by the
base-overlay policy.

Candidate admission is not release promotion. A K230 device must still verify
`tdvp-bc --version`, an arbitrary-precision expression, uninstall, and
rollback before a signed public feed release can include this package.
