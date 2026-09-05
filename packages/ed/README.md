# GNU ed line-editor candidate

`ed` uses the GNU 1.20.2 archive and runner-only host-lzip input recorded in
`source.lock`, in a private GitHub Actions Buildroot transaction. The IPK owns
only `/usr/libexec/tdvp-ed/ed` and exposes `/usr/bin/tdvp-ed`; it neither
replaces a firmware path nor provides a shared library.

CI builds and audits the ELF but never invokes `ed` or supplies a file. Device
use requires an approved target, install/uninstall/rollback evidence, and must
not be inferred from this candidate build.
