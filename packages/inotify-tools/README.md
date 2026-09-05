# inotify-tools filesystem-event candidate

`inotify-tools` uses the GitHub 3.20.2.2 release archive recorded in
`source.lock` and Buildroot 2025.02.1 only in a private GitHub Actions
transaction. It disables shared output and forces the command executables to
use the private static implementation; no `libinotifytools` library or
development header is part of the IPK.

The IPK owns only source-built `inotifywait` and `inotifywatch` below
`/usr/libexec/tdvp-inotify-tools/`. The sole public commands are
`/usr/bin/tdvp-inotify-wait` and `/usr/bin/tdvp-inotify-watch`; it does not
replace a firmware command or become a shared runtime provider.

CI builds and audits the commands but never starts a watcher, supplies a path,
or observes any filesystem event. Device use must name an approved directory
and include install/uninstall/rollback evidence before a signed release is
considered.
