# logrotate log-maintenance candidate

`logrotate` uses the GitHub 3.22.0 release archive recorded in `source.lock`
and Buildroot 2025.02.1 only in a private GitHub Actions transaction. The
recipe consumes the immutable target `libpopt` provider and explicitly
disables the optional SELinux and ACL branches.

The IPK owns only the source-built command below
`/usr/libexec/tdvp-logrotate/logrotate`. Its sole public command is
`/usr/bin/tdvp-logrotate`; it does not replace a firmware command or establish
a shared runtime provider. Neither `/etc/logrotate.conf` nor
`/etc/logrotate.d` is packaged, and this IPK supplies no timer, daemon, or
default rotation policy.

CI builds and audits the command but never invokes it, passes it a path, or
allows it to read, rename, compress, remove, or rotate a log. Device use must
provide an approved configuration and include install/uninstall/rollback
evidence before a signed release is considered.
