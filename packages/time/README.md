# GNU time candidate

`time` uses the GNU 1.9 archive recorded in `source.lock`, in a private
GitHub Actions Buildroot transaction. The IPK owns only
`/usr/libexec/tdvp-time/time` and exposes `/usr/bin/tdvp-time`; it neither
replaces a firmware path nor provides a shared library.

CI builds and audits the ELF but never invokes `time` or starts a command for
it to measure. Device use requires an approved target, install/uninstall/
rollback evidence, and must not be inferred from this candidate build.
