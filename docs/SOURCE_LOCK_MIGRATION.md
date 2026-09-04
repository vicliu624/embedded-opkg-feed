# Historical recipe source-lock migration ledger

[中文](SOURCE_LOCK_MIGRATION.zh-CN.md) | [English (current)](SOURCE_LOCK_MIGRATION.md)

This ledger supplements the [upstream-source admission and reproducible
packaging policy](UPSTREAM_SOURCES.md). It addresses historical migration: an
old recipe with an `r9` or `r10` label does **not** automatically meet the new
source-supply-chain rule merely because its directory exists. Only a package
with a valid `source.lock`, or a pure TDVP profile with a narrow explicit
`SOURCE_LOCK_EXEMPT_REASON`, is an eligible input to a source-lock candidate.

After adding or migrating a recipe, maintainers run:

```sh
bash ./scripts/verify-source-lock.sh --repo-root . --all
find packages -mindepth 2 -maxdepth 2 -name package.env -type f | LC_ALL=C sort
```

The first command validates every committed lock; the second prompts review of
the package inventory and this ledger. CI requires a lock for changed
third-party recipes, so an unfinished historical migration never exempts a new
or changed upstream import.

## Migrated, offline-auditable foundation

The following r9/r10 packages have `source.lock` records and can enter the
offline cross-build path after their HTTPS content-addressed source-cache
artifacts are verified. The separately named `libatomic-1` item is the one
reviewed matched-target runtime transfer, with its narrower evidence described
below; it is not an upstream-source exception for ordinary packages.

- Buildroot-derived maintenance commands: `make`, `pkgconf`, `patch`,
  `diffutils`, and `strace`;
- r10 text/search/terminal-diagnostic commands: `tree`, `less`, `file`,
  `which`, `curl`, `wget`, `iperf3`, `lsof`, `netcat`, `rsync`, `dos2unix`, `jq`, `grep`, `sed`, `findutils`, `gawk`, `htop`, `nano`, and `tmux`;
  `nano`; `htop` explicitly disables the unadmitted optional `libcap` feature,
  while `nano` preserves the current SDK's disabled file/libmagic integration;
  both reuse only the owned `libncursesw` runtime;
- terminal Vim: `vim-runtime` and `vim`; both lock the same reviewed
  Buildroot 2025.02.1 Vim 9.1.0145 source archive and cross-build it through
  a private offline `BR2_DL_DIR`. `vim-runtime` owns only runtime data and the
  license, while `vim` owns only the private ELF, `/usr/bin/vim` wrapper, and
  TDVP configuration. Its sole non-platform ELF dependency is the owned
  `libncursesw`, and the resulting ELF has been audited to contain no
  RPATH/RUNPATH;
- shared TLS trust store: `ca-certificates`; it builds from the locked Debian
  20230311 source snapshot, with the matching SDK's `c_rehash` generating the
  `/etc/ssl/certs` bundle and hash links in a private target root. The package
  owns both those links and their `/usr/share/ca-certificates` targets, so it
  never relies on certificate files left by an old release or base firmware;
- SSH transport client: `openssh-client`; it cross-builds locked OpenSSH 9.9p2
  source directly with the matching SDK/sysroot and the reviewed Buildroot
  options, explicitly avoiding this desktop SDK's unrelated PAM/server graph.
  Its payload is limited to `ssh`, `scp`, `sftp`, `ssh-agent`, and `ssh-add`;
  it contains no server, setuid helper, key-generation utility, or `/etc/ssh`
  configuration. All five RISC-V ELFs were audited with no RPATH/RUNPATH and
  exact owned OpenSSL/zlib dependencies;
- Git client split: `git-runtime` and `git`; both lock the Git 2.48.1 release
  archive selected and hashed by Buildroot 2025.02.1, then cross-build it
  directly against the matching SDK/sysroot and a verified offline source
  cache. `git` owns only `/usr/bin/git`; `git-runtime` owns an explicit client
  helper/template allowlist, with its `git-core/git -> ../../bin/git` link
  removing the duplicate frontend. The resulting RISC-V IPKs have no
  RPATH/RUNPATH and exact providers for curl, Expat, OpenSSL, PCRE2, zlib, CA
  certificates, and OpenSSH. They deliberately exclude `git-daemon`, HTTP
  backend/CGI, `git-shell`, Gitweb, browser launchers, and Perl/Python/Tcl/Tk
  tools; see [`packages/git/README.md`](../packages/git/README.md) for the
  split and validation boundary;
- Git forge client: `gh` locks the immutable GitHub CLI 2.98.0 source archive
  and records the official Go 1.26.7 linux/amd64 archive as a **host-only**
  compiler input that never enters a target tree or IPK. `go-modules.lock`
  locks the upstream `go.mod`/original `go.sum`, Go's resolved `go.sum`,
  `vendor/modules.txt`, the 179-module vendor set, and the deterministic vendor
  bundle SHA-256. Cache seeding may access the Go proxy only while all of those
  hashes match; the final linux/riscv64 build uses an empty `GOMODCACHE`,
  `GOPROXY=off`, `GOSUMDB=off`, and `-mod=vendor`. A 36 MB static RISC-V ELF
  and candidate IPK have no dynamic libraries or RPATH/RUNPATH. Matching-K230
  SDK and on-device HTTPS/SSH/install/uninstall/rollback gates still precede
  publication;
- foreign-function interface runtime: `libffi-8` locks the Buildroot 2025.02.1
  reviewed libffi 3.4.6 archive and materialises only the public
  `libffi.so.8 -> libffi.so.8.1.4` ABI in a dedicated IPK. Its source-cache
  build and candidate IPK audit establish it as the unique reusable provider
  for CPython `_ctypes` and later FFI consumers: the payload is RISC-V ELF64,
  has no RPATH/RUNPATH, and needs only the TDVP platform ABI. It must not be
  copied privately into an interpreter package or borrowed from firmware;
- SQL database runtime: `libsqlite3-0` locks the Buildroot 2025.02.1 reviewed
  SQLite 3.48.0 archive and materialises only
  `libsqlite3.so.0 -> libsqlite3.so.0.8.6`. Its verified offline source build
  and candidate audit make it the unique reusable provider for CPython
  `_sqlite3` and later database clients. The RISC-V ELF has no RPATH/RUNPATH
  and declares its exact `libz` provider; the `sqlite3` CLI, development
  headers, static archive, and staging metadata are deliberately excluded;
- decimal arithmetic runtime: `libmpdec-4` locks the Buildroot 2025.02.1
  reviewed mpdecimal 4.0.0 archive and materialises only
  `libmpdec.so.4 -> libmpdec.so.4.0.0`. The candidate is a RISC-V ELF64 shared
  object with no RPATH/RUNPATH and only platform ABI dependencies, making it
  the unique reusable provider for CPython `_decimal`. Its C++ ABI, headers,
  pkg-config data, documentation, and staging files are explicitly excluded;
- CPython language runtime split: `libpython3.13`, `python3-runtime`, and
  `python3` lock the same CPython 3.13.3 release archive selected and hashed by
  Buildroot 2025.02.1, but the feed directly cross-builds it with the matching
  SDK/sysroot rather than enabling Buildroot's Python package or copying its
  target root. The packages respectively own the public `libpython3.13` ABI,
  the standard library/native extensions, and only the command frontends. The
  recipe requires the separately owned OpenSSL, libffi, mpdecimal, SQLite,
  compression, ncurses/readline, zlib, and Expat providers; `pyexpat` is
  verified to need `libexpat.so.1`, while `_elementtree` uses CPython's pyexpat
  C-API hook. Private Expat, `_curses_panel`/unowned `libpanelw`, IDLE, pydoc,
  tkinter, ensurepip, static/development files, and build metadata are excluded.
  The split and remaining release gates are documented in
  [`packages/python3/README.md`](../packages/python3/README.md);
- Node.js provider foundation: `libcares`, `libuv`, and `libnghttp2` each lock
  and directly cross-build their own official source archive into the unique
  `libcares.so.2`, `libuv.so.1`, and `libnghttp2.so.14` providers. Their
  candidate RISC-V IPKs were audited without RPATH/RUNPATH and carry only the
  platform-ABI closure. `libuv` is locked at 1.51.0 because Node 22.23.2 uses
  its public `UV_TTY_MODE_RAW_VT` API; matching the SONAME alone is not enough
  to establish a valid build-time API contract. `libicudata`, `libicuuc`, `libicui18n`, and `libicuio`
  also lock the ICU 73.2 archive; because ICU needs a host/target two-stage
  build, they currently invoke the reviewed Buildroot recipe only through a
  private offline download directory, then split the four public SONAMEs. The
  four candidate IPKs were audited as RISC-V ELF64 with exact ICU and
  `libatomic-1` dependencies. `libnode`, `node`, `npm-runtime`, and `npm` lock
  the same Node 22.23.2 release archive; each records the reviewed
  `patches/node22-lazy-bz2-import.patch` hash. The patch moves Node's `bz2`
  import into the embedded-ICU data-expansion branch: the feed selects
  `--with-intl=system-icu`, so it does not change the selected source or
  bypass ICU, but lets the SDK's otherwise suitable Python 3.13 run the
  configuration without an unused `_bz2` extension. It also scopes the
  target shared-library flags to non-host GYP toolsets, so native V8 generator
  executables never attempt to link RISC-V libraries while the target still
  receives the complete explicit closure. The host toolset instead receives
  the x86_64 ICU 73.2 produced by the same locked Buildroot ICU transaction;
  it is a build tool input and is never packaged or copied to the device. Its
  host toolset also builds a static x86_64 libuv from the same locked Node
  release archive solely for the native generators; that archive and its
  headers are host-only inputs, never a target provider or IPK payload. Its
  recorded host inputs require native GCC/G++ 10 or newer for V8 generators,
  SDK Python 3.8 or newer, and the reviewed QEMU action wrapper. The Node
  builder rejects an
  absent direct-source staging marker for the three network providers and
  links them from that release staging sysroot, never from a prebuilt Node
  binary or a second Buildroot target copy. A complete Node candidate and
  target lifecycle record remain a promotion gate;
- required shared runtimes: `libz`, `libmagic`, `libjq`, `libpcre2-8`,
  `libncursesw`, `libreadline`, `libbz2`, `liblzma`, `libzstd`,
  `libexpat-1`, `libcrypto-3`, `libssl-3`, `libcurl-4`, `libffi-8`, and
  `libsqlite3-0`, and `libmpdec-4`.
  `libexpat-1` is
  the independent `libexpat.so.1` provider for Git XML parsing; it has been
  built offline and audited to need only the platform libc/libm/loader.
  OpenSSL 3.4.1 is split into the unique `libcrypto.so.3` and `libssl.so.3`
  providers; the latter has an exact dependency on the former. `libcurl-4`
  is built offline from locked curl 8.12.1 source with the reviewed minimal
  HTTPS configuration; it owns `libcurl.so.4` and has exact runtime
  dependencies on the CA store, OpenSSL, `libzstd`, `libz`, and `libatomic-1`.
  The adjacent source-admitted `curl` leaf enables `BR2_PACKAGE_LIBCURL_CURL`
  only in that same private Buildroot transaction and may copy only the staged
  `/usr/bin/curl` frontend after verifying the staging proof, RISC-V ELF type,
  `libcurl.so.4` dependency, and RPATH/RUNPATH policy. Its actual candidate
  IPK still requires a matching K230 SDK build and device lifecycle evidence.
  Optional c-ares, IDN, PSL, libssh2, Brotli, nghttp2, GSASL, and RTMP support
  are not selected in the reviewed libcurl candidate;
- source-admitted GNU Wget command: `wget` locks Wget 1.25.0 and host-pkgconf
  2.3.0. It requires a matching SDK with OpenSSL/libOpenSSL and zlib, then
  explicitly turns off PSL, GnuTLS, IDN2/IRI, c-ares, PCRE/PCRE2, and libuuid
  before its private Buildroot transaction. It packages no shared library and
  relies only on the separately owned CA, OpenSSL, and zlib providers. Its
  actual candidate IPK still requires the matching K230 SDK and device
  lifecycle evidence;
- source-admitted network diagnostic: `iperf3` locks the iperf3 3.18 archive
  selected by Buildroot 2025.02.1. Its required matching-SDK toolchain
  capabilities (threads and atomics) are checked before the transaction, and
  the optional OpenSSL authentication mode is explicitly disabled. It has no
  additional feed runtime dependency and packages only the private command;
  its actual candidate IPK still requires the matching K230 SDK and device
  lifecycle evidence;
- source-admitted open-file diagnostic: `lsof` locks the lsof 4.99.4 archive
  selected by Buildroot 2025.02.1. It checks the matching SDK's MMU capability
  and explicitly disables optional libtirpc linkage, leaving only the Linux
  /proc command with no added feed runtime provider. Its actual candidate IPK
  still requires matching-K230 SDK and on-device privilege/visibility evidence;
- source-admitted connection diagnostic: `netcat` locks the GNU Netcat 0.7.1
  archive selected by Buildroot 2025.02.1. Its target recipe has no optional
  shared-library closure; its `nc` command is still private to the IPK and
  must pass the base-overlay collision check before publication. Device tests
  use only controlled endpoints and never expose an unauthenticated listener;
- source-admitted terminal multiplexer: `libevent` uniquely owns its four
  public event-loop SONAMEs with optional OpenSSL support disabled. `tmux`
  then declares exact libevent/libncursesw dependencies and locks tmux,
  libevent, and host-pkgconf archives; it checks matching-SDK MMU, wchar,
  locale, and ncurses capabilities and disables systemd/utf8proc. Actual IPKs
  still require matching-SDK and on-device session lifecycle evidence;
- metadata-only diagnostic profile: `tdvp-diagnostics` has a narrow source-lock
  exemption because it contains only repository-owned instructions and exact
  `strace`/`htop`/`lsof`/`iperf3`/`netcat` dependency metadata. It owns no executable,
  shared library, SDK artifact, or firmware path;
- source-admitted rsync split: `libpopt` locks the popt 1.19 source and is the
  unique `libpopt.so.0` provider, with external libiconv explicitly disabled.
  `rsync` locks rsync 3.4.1, popt, zlib, host-pkgconf, and the reviewed
  Buildroot autoreconf patch. It depends on `libpopt`, `libz`, and
  `openssh-client`, and explicitly disables ACL, LZ4, OpenSSL daemon TLS,
  xxHash, and Zstd. The recipes reject both a changed Buildroot patch and a
  candidate SDK without zlib; actual candidate IPKs still require a matching
  K230 SDK and device lifecycle evidence;
- matched target-derived compiler runtime: `libatomic-1`, the sole explicit
  non-profile `SOURCE_LOCK_EXEMPT_REASON`. It transfers only
  `libatomic.so.1 -> libatomic.so.1.2.0` from the completed matching target;
  the recipe verifies the pinned Xuantie GCC 14.1.1 identity, target
  configuration, SHA-256, SONAME, ELF ABI, RPATH absence, symlink target, and
  final byte-identical base-overlay result. It is a unique feed owner for a
  non-ABI SONAME—not a replacement of glibc, the loader, `libgcc_s`, or any
  other ABI seed;
- archive command suite: `archive-tools`, locking tar, gzip, bzip2, xz,
  zstd, zip, unzip, the Debian unzip patch archive, and p7zip inputs; and
- migrated pure-Vimscript runtime plugins: `vim-plugin-commentary`,
  `vim-plugin-repeat`, `vim-plugin-sleuth`, `vim-plugin-surround`, and
  `vim-plugin-gitgutter`.

“Offline-auditable” means the source, cross-build, and package-closure gates
can run. It does not replace full target install/uninstall, functional test,
signature, and release evidence for each release.

## Explicit exemptions

`tdvp-source-tools`, `tdvp-dev-tools`, and `tdvp-nodejs-tools` install only
repository-owned README material or exact dependency metadata. They do not
download or package third-party source and therefore record the narrow
`SOURCE_LOCK_EXEMPT_REASON`. Every third-party dependency of a profile must
still own its own lock; a profile exemption never propagates to `git`, `node`,
`vim`, or another package that imports upstream source.

`libatomic-1` is the only other exemption. Unlike a profile it contains a
runtime object, but its recipe is a constrained transfer under the
shared-runtime contract: it copies no arbitrary or foreign prebuilt binary and
must reproduce the byte-identical `libatomic.so.1.2.0` already emitted by the
declared matching platform target. A changed toolchain, configuration, hash,
SONAME, ELF ABI, mode, or symlink makes the build fail. It does not establish a
general exemption for compiler runtimes or target-rootfs copies.

## Next high-value source groups to migrate

These remain historical recipes and have not yet completed source-lock
candidate admission. Migrate them with shared runtimes before leaf
applications; do not promote them to a new source-lock release until their
locks, offline build, and target validation are complete.

| Batch | Packages | Preconditions and reason |
| --- | --- | --- |
| Node.js release proof | `libnode`, `node`, `npm-runtime`, `npm` | Provider source locks and staged ABI boundary are complete. Build the complete locked Node 22.23.2 candidate, audit its final ELF closure, then perform K230 install/core-function/uninstall/rollback testing before promotion. |
| Multimedia/desktop | `audacious-*`, `sdl2*`, `tdvp-mpv`, `tdvp-netsurf` | The Wayland/graphics ABI graph needs a complete matching SDK/sysroot and on-device desktop acceptance. |

## Promotion rule

“Migrated” is not “released.” A batch enters a release candidate only when
every imported-source package locks its source and patches, offline source-cache
rebuild succeeds, every non-platform SONAME has one owner, the IPKs have no
protected-path changes or RPATH/RUNPATH, a complete matching K230 target passes
install/core-function/uninstall/rollback tests, and it is then signed into an
immutable release.
