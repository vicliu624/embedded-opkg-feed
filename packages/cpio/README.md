# GNU cpio candidate

`cpio` uses the GNU 2.15 archive recorded in `source.lock`, in a private
GitHub Actions Buildroot transaction. The IPK owns only
`/usr/libexec/tdvp-cpio/cpio` and exposes `/usr/bin/tdvp-cpio`; it neither
replaces a firmware path nor provides a shared library.

CI builds and audits the ELF but never invokes `cpio`, supplies an archive, or
provides a filesystem path. Device use requires an approved target,
install/uninstall/rollback evidence, and must not be inferred from this
candidate build.
