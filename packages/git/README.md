# Git 2.48.1 client split

`git` and `git-runtime` are one locked Git 2.48.1 source build divided into
two IPKs:

- `git` owns only `/usr/bin/git`, the public RISC-V frontend.
- `git-runtime` owns the client transport helpers, shell workflow helpers,
  merge-tool definitions, and Git templates below `/usr/libexec/git-core` and
  `/usr/share/git-core`.

The runtime's `git-core/git` is a relative `../../bin/git` link. This removes
a duplicate frontend binary; `git` has an exact dependency on `git-runtime`,
so ordinary `opkg install git` installs both before Git is run. `git-runtime`
is an implementation dependency, not a standalone user-facing package.

The build retains ordinary local repositories, HTTPS/HTTP/FTP remote helpers,
SSH remotes through `openssh-client`, submodules, difftool/mergetool data, and
the standard `git init` templates. It deliberately does **not** publish
`git-daemon`, `git-http-backend`, `git-shell`, `git-cvsserver`, Gitweb,
browser launchers, or Perl/Python/Tcl/Tk-specific tools. Those are server or
optional interpreter/desktop features and need a separately admitted package
and target validation if ever required.

The source archive is verified through both `source.lock` records and the
content-addressed TDVP source cache. Buildroot 2025.02.1 provides the reviewed
version/hash and feature knowledge, but the recipe directly cross-builds with
the matching TDVP SDK/sysroot rather than enabling the SDK's global Git
package graph. The runtime package checks every target ELF for RISC-V ABI and
removes any build-time RPATH/RUNPATH before packaging.
