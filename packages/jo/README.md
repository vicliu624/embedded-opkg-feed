# jo JSON-construction candidate

`jo` uses the GitHub 1.6 release archive recorded in `source.lock` and
Buildroot 2025.02.1 only in a private GitHub Actions transaction. It is a
single command with no non-platform shared-runtime provider.

The IPK owns only the source-built executable below `/usr/libexec/tdvp-jo/`.
Its sole public command is `/usr/bin/tdvp-jo`; it does not replace a firmware
path or establish a shared runtime provider.

CI builds and audits the command but never invokes it or provides JSON input.
Device use must include install/uninstall/rollback evidence before a signed
release is considered.
