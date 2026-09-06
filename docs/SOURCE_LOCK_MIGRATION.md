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
- TLS trust store: `ca-certificates` is owned by the fixed K230 target
  catalogue's `/etc/ssl` data. Run `33977596329` proves that selecting its
  same-named source recipe retains the target provider and stops; it is not a
  source candidate and must not be replaced by a Debian-source or host-made
  bundle;
- OpenSSH client (namespaced candidate; ordinary paths are not admitted):
  `openssh-client` locks the portable 9.9p2 archive and limits its source
  build to `ssh`, `scp`, `sftp`, `ssh-agent`, and `ssh-add`. GitHub Actions
  run `33977961721` completed the cross-build but rejected the non-identical
  `/usr/bin/ssh-agent` payload against the fixed target with exit 79. Those
  ordinary paths remain excluded. The separate `secure-transfer-tools`
  candidate may retain RISC-V ELFs only below `/usr/libexec/tdvp-openssh-client/`
  and expose `tdvp-ssh`, `tdvp-scp`, `tdvp-sftp`, `tdvp-ssh-agent`, and
  `tdvp-ssh-add` wrappers. It still requires a new GitHub Actions source,
  closure, deny-overlay, IPK-index, and no-recompile merge admission. Run
  [`33981065347`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347)
  completed that one client closure from the locked source, recorded the
  private payload, passed feed verification, and uploaded
  `openssh-client_9.9p2-1_riscv64.ipk` in artifact
  [`9973816789`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981065347/artifacts/9973816789)
  (91,164,015 bytes). No-recompile 20-batch merge run
  [`33981319632`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632)
  then compared every IPK hash, rebuilt the index, and validated runtime
  closure/target coverage before uploading merged artifact
  [`9973893992`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33981319632/artifacts/9973893992)
  (194,733,782 bytes). Both remain unsigned candidates; neither signing,
  release/publishing, deployment, nor device execution occurred;
- media-inspection leaf (candidate): `ffprobe` is migrated from its r7 recipe
  to r10 with the Buildroot 2025.02.1 FFmpeg 4.4.4 archive/hash locked. It
  stages only the `ffprobe` frontend. Run `33978610176` completed the RISC-V
  FFmpeg build but stopped when the restored SDK lacked the Buildroot Debian
  side-artifact directory (exit 2), so it uploaded no artifact. The retry
  creates that non-payload directory only in the Actions SDK workspace. Retry
  run `33979150084` passed source, RISC-V, runtime-closure, deny-overlay, and
  feed verification gates and uploaded batch artifact `9973352053` containing
  `ffprobe_4.4.4-1_riscv64.ipk`; no-recompile 18-batch merge run `33979683310`
  then succeeded and uploaded merged artifact `9973413113`. It remains an
  unsigned candidate, with no signing, release/publishing, or on-device
  lifecycle evidence;
- r10 text/search/terminal-diagnostic commands: `tree`, `less`, `file`,
  `which`, `curl`, `wget`, `iperf3`, `lsof`, `netcat`, `rsync`, `dos2unix`, `jq`, `grep`, `sed`, `findutils`, `gawk`, `htop`, `nano`, and `tmux`;
  htop's capability view may use only the immutable target-catalogue
  `libcap-2 (= 2025.02.1-1)` / `libcap.so.2` owner; it never rebuilds,
  replaces, or implicitly borrows that firmware ABI. Run
  [`33982220719`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982220719)
  correctly rejected an attempted `2.73-1` source provider at the owner map
  before compiling or uploading an artifact. The corrected
  `process-monitoring-tools` completed GitHub Actions htop source/closure/
  deny-overlay admission in run
  [`33982469638`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638),
  uploading unsigned batch artifact
  [`9974194807`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982469638/artifacts/9974194807)
  (90,244,788 bytes). The no-recompile 21-batch merge in run
  [`33982760512`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512)
  compared every input IPK hash, re-indexed, and validated closure/base-overlay;
  it uploaded merged unsigned artifact
  [`9974285835`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33982760512/artifacts/9974285835)
  (194,891,156 bytes). Both remain unsigned candidates: neither was signed,
  released/published, deployed, nor executed on a device. `nano`
  preserves the current SDK's disabled file/libmagic integration; both reuse
  only the owned `libncursesw` runtime;
- terminal Vim: `vim-runtime` and `vim`; both lock the same reviewed
  Buildroot 2025.02.1 Vim 9.1.0145 source archive and cross-build it through
  a private offline `BR2_DL_DIR`. `vim-runtime` owns only runtime data and the
  license, while `vim` owns only the private ELF, `/usr/bin/vim` wrapper, and
  TDVP configuration. Its sole non-platform ELF dependency is the owned
  `libncursesw`, and the resulting ELF has been audited to contain no
  RPATH/RUNPATH;
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
- source-admitted terminal multiplexer: `libevent` is a locked-source shared
  provider for its four public event-loop SONAMEs, while `tmux` declares exact
  libevent/target-catalogue-libncursesw dependencies. Its Buildroot 2025.02.1
  closure locks tmux, libevent, host-pkgconf, and the OpenSSL archive matching
  libevent's target-attested libcrypto closure. tmux does not link OpenSSL or
  systemd directly and must not override the matching SDK's global feature
  choices: recipe-scoped `TMUX_CONF_OPTS` disables systemd/utf8proc and the
  fixed `TMUX_DEPENDENCIES` prevents their build-time import. GitHub Actions
  [run `33985238251`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251)
  completed the matching-SDK cross-build, RISC-V ELF, closure, and deny-overlay
  gates and uploaded unsigned batch artifact
  [`9974999937`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985238251/artifacts/9974999937)
  (90,887,183 bytes). The 23-batch no-recompile merge,
  [run `33985545990`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990),
  compared every input IPK SHA-256, re-indexed, and validated closure/base-overlay
  without a build job; it uploaded merged unsigned artifact
  [`9975077200`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33985545990/artifacts/9975077200)
  (195,989,739 bytes). All artifacts remain unsigned, unreleased, undeployed,
  and require on-device session lifecycle evidence;
- incremental metadata profiles: a dependent profile such as
  `tdvp-diagnostics` must provide `base_merged_run_id` to the GitHub Actions
  batch. CI accepts only one live merged-unsigned artifact from a successful
  run and rejects ambiguous feed paths/top-level symlinks. When a prior
  artifact repeats a target-runtime IPK, CI retains the newly restored,
  authoritative target base rather than importing or comparing that
  target-derived container duplicate; it hydrates only absent source-built
  IPKs before building the profile. This makes the profile dependency closure
  verifiable without recompiling historical source packages. GitHub Actions
  [run `33987100478`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987100478)
  applied this rule to successful merged run `33985545990`: it hydrated 276
  verified IPKs, retained the newly restored target-runtime duplicates, and
  built only `tdvp-diagnostics_1.1-1_riscv64.ipk`. It uploaded unsigned
  batch artifact
  [`9975532821`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987100478/artifacts/9975532821)
  (196,004,873 bytes); no historical source package was rebuilt. The subsequent
  24-batch no-recompile merge,
  [run `33987408229`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229),
  skipped both SDK/package-build jobs, compared the input IPK hashes, regenerated
  the index, and passed runtime closure plus target-runtime coverage. It uploaded
  merged unsigned artifact
  [`9975645724`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33987408229/artifacts/9975645724)
  (195,991,913 bytes). Neither artifact is signed, released/published, deployed,
  installed, nor supported by on-device lifecycle evidence;
- metadata-only diagnostic profile: `tdvp-diagnostics` has a narrow source-lock
  exemption because it contains only repository-owned instructions and exact
  `strace`/`htop`/`lsof`/`iperf3`/`netcat` dependency metadata. It owns no executable,
  shared library, SDK artifact, or firmware path;
- target-attested rsync dependencies: the immutable catalogue is the unique
  `libpopt.so.0` / `libz.so.1` / `libcrypto.so.3` provider at
  `libpopt (= 1.19-1)`, `libz (= 1.3.1-1)`, and `libcrypto-3 (= 3.4.1-1)`.
  The matching SDK restores the locked Buildroot rsync OpenSSL branch, so
  rsync consumes that exact crypto ABI rather than trying to disable global
  Kconfig or rebuild any of these runtimes. It locks rsync 3.4.1, popt, zlib,
  OpenSSL, host-pkgconf, and the reviewed Buildroot autoreconf patch. Its
  remote shell is deliberately not an OpenSSH package dependency: it uses
  platform `ssh` by default or an explicitly requested `-e /usr/bin/tdvp-ssh`
  transport. It explicitly disables ACL, LZ4, xxHash, and Zstd. The recipes
  reject both a changed Buildroot patch and a candidate SDK without zlib. The
  first remote audit, [run `33983507607`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983507607),
  correctly deferred all three target providers but stopped before an artifact
  when the former recipe asserted that Buildroot had disabled OpenSSL. The
  corrected exact-libcrypto revision completed in
  [run `33983785585`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585)
  and uploaded unsigned batch artifact
  [`9974581047`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33983785585/artifacts/9974581047)
  (90,386,375 bytes). The no-recompile 22-batch merge,
  [run `33984054059`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059),
  compared every input IPK hash, re-indexed, and validated closure/base-overlay;
  it uploaded merged unsigned artifact
  [`9974652475`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33984054059/artifacts/9974652475)
  (195,190,117 bytes). Both artifacts remain unsigned, unreleased/unpublished,
  undeployed, and unexecuted on a device; on-device lifecycle evidence remains
  required;
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

## Next high-value source groups

Node.js and the multimedia/desktop graph are no longer un-migrated historical
recipes: their r10 source batches are already part of the successful
24-batch unsigned merge. Their remaining work is device lifecycle validation,
not a second source build.

The following post-merge expansion is documented separately so that a prepared
recipe is never confused with an admitted candidate. It must still pass a
GitHub Actions source batch and later a no-recompile merge before it receives
candidate evidence.

| Batch | Packages | Preconditions and reason |
| --- | --- | --- |
| Debug/network diagnostics | `gdbserver`, `ethtool` | GitHub Actions source batch [`33988534267`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267) passed with the locked Buildroot 2025.02.1 sources and private TDVP frontends; 25-batch no-recompile merge [`33988940718`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718) then admitted the verified IPKs. `gdbserver` remained server-only without changing the SDK host debug-root; `ethtool` retained its no-netlink/no-libmnl boundary. CI did not start a server or change an interface; device lifecycle validation remains required. |
| I2C hardware inspection | `i2c-tools` | GitHub Actions source batch [`33989899026`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026) passed the reviewed static-only leaf: Python/py-smbus was disabled, the five commands linked private `libi2c.a`, and neither `libi2c.a` nor `libi2c.so` was packaged. 26-artifact no-recompile merge [`33990178543`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543) then admitted the verified IPK. CI did not probe or write a bus; device lifecycle validation remains required. |
| Filesystem event inspection | `inotify-tools` | GitHub Actions source batch [`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904) passed the reviewed private command leaf: shared output was disabled, the private libinotifytools implementation was linked into `inotifywait`/`inotifywatch`, and no `libinotifytools` or headers were packaged. The 27-artifact no-recompile merge [`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095) then admitted the verified IPK. CI did not start a watcher or observe a path; device lifecycle validation remains required. |
| Log maintenance | `logrotate` | GitHub Actions source batch [`33991963284`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991963284) passed the reviewed command-only leaf: it reused the immutable target `libpopt` provider, disabled SELinux/ACL, and packaged only a private `logrotate` ELF with the `tdvp-logrotate` frontend. No `/etc/logrotate.conf`, `/etc/logrotate.d`, timer or daemon was included. The 28-artifact no-recompile merge [`33992249214`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992249214) then admitted the verified IPK. CI did not invoke it or rotate a log; device lifecycle validation remains required. |
| JSON construction | `jo` | GitHub Actions source batch [`33992855036`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992855036) passed the reviewed standalone command leaf: it packaged only private `jo` with the `tdvp-jo` frontend and introduced no shared-runtime provider. The 29-artifact no-recompile merge [`33993109744`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993109744) then admitted the verified IPK. CI did not invoke it or provide JSON input; device lifecycle validation remains required. |
| Line editing | `ed` | GitHub Actions source batch [`33993563150`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993563150) passed the reviewed GNU command leaf: runner-only host-lzip unpacked the locked archive, then only private `ed` with the `tdvp-ed` frontend was packaged. No shared provider was introduced. The 30-artifact no-recompile merge [`33993808518`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33993808518) then admitted the verified IPK; CI did not invoke it or give it a file. |
| Archive interchange | `cpio` | GitHub Actions source batch [`33994423195`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33994423195) passed the reviewed GNU command leaf: its glibc/wchar K230 profile did not select the musl/uClibc-only argp-standalone branch, then only private `cpio` with the `tdvp-cpio` frontend was packaged. No shared provider was introduced. The 31-artifact no-recompile merge [`33994729377`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33994729377) then admitted the verified IPK; CI did not invoke it, provide an archive, or provide a filesystem path. |
| Process timing | `time` | GitHub Actions source batch [`33995251958`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33995251958) passed the reviewed GNU command leaf: the K230 MMU/dynamic-library/BusyBox-show-others profile satisfied its upstream conditions, then only private `time` with the `tdvp-time` frontend was packaged. No shared provider was introduced. The 32-artifact no-recompile merge [`33995532939`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33995532939) then admitted the verified IPK; CI did not invoke it or start a command for it to measure. |
| CPU limiting | `cpulimit` | GitHub Actions source batch [`33996029211`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33996029211) passed the reviewed private command leaf. It introduces no shared provider; the 33-artifact no-recompile merge [`33996322817`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33996322817) then admitted the verified IPK. CI did not invoke it, supply a PID/process name, start a process, or throttle a process. |
| Bandwidth monitoring | `bwm-ng` | GitHub Actions source batch [`33997001920`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33997001920) passed the reviewed private command leaf and produced unsigned artifact [`9978397329`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33997001920/artifacts/9978397329) (90,164,043 bytes; SHA-256 `affabae7d97bb5778227d09ae634d867a17f11f9b5a32d6d68f568a6b91fb373`). Its optional terminal view consumes only the immutable target `libncursesw` provider; it builds and publishes no runtime provider. The 34-artifact no-recompile merge [`33997364665`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33997364665) then admitted the verified IPK, rebuilt the index, and passed runtime closure plus 445-object target coverage; merged artifact [`9978511004`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33997364665/artifacts/9978511004) has SHA-256 `ffeb22475b948bc57064df291f8783f5006128c2965cab9feddb73bb766472c0`. CI did not invoke it, read procfs, observe a network interface, or observe disk I/O; device lifecycle validation remains required. |
| Checksum verification | `rhash` | GitHub Actions source batch [`33998249379`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33998249379) passed the reviewed private command leaf and produced unsigned artifact [`9978739567`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33998249379/artifacts/9978739567) (90,288,593 bytes; SHA-256 `85f7c5752bfadd140bd9a34c9c7cc7069890461e23f57b5f5e63e9b670ae65c3`). The recipe disables gettext/OpenSSL, statically links the private librhash implementation, and disables its shared-library build, so it introduces no provider. The 35-artifact no-recompile hash merge [`33998522557`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33998522557) then admitted the verified IPK, rebuilt the index, and passed runtime closure plus 445-object target coverage; merged artifact [`9978839795`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33998522557/artifacts/9978839795) has SHA-256 `6042b30b4b5e9af1d46b50c8b0a18a8e20564e189919feb5734c103251bcb14e`. CI did not invoke it or supply a file path/payload; device lifecycle validation remains required. |
| Fast non-cryptographic integrity | `xxhash` | Buildroot 2025.02.1 locks xxHash 0.8.3 and its GitHub tag archive SHA-256 is `aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80`. GitHub Actions source batch [`34000078942`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34000078942) restored (and did not rebuild) the SDK, used the RISC-V toolchain to build/link only `xxhsum`, and uploaded `xxhash_0.8.3-1_riscv64.ipk` in unsigned artifact [`9979257288`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34000078942/artifacts/9979257288) (90,122,393 bytes; GitHub SHA-256 `614f484c613a024b831ff62f3e2f440259f5260788ad28dd01756b977632c2f6`). The reviewed transaction does not build/install `libxxhash`, headers, or pkg-config metadata, and the run passed source cache, RISC-V ELF, closure, deny-overlay, feed-verification, and 445-object target-coverage gates. No-recompile merge [`34000394791`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34000394791) compared all 36 artifact manifests/IPK hashes, rebuilt the index, and again passed closure/445-object coverage without compiling; it uploaded merged artifact [`9979351229`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34000394791/artifacts/9979351229) (196,935,108 bytes; GitHub SHA-256 `0c2ae26b0841902ca0e850ddb76306aaba64732e2ec8715b3240396ec5f19b7b`). `xxhsum` is restricted to controlled deduplication and non-security prefiltering, never authentication, signatures, or security decisions. Device lifecycle validation remains required. |
| Socket relay (deferred) | `socat` | Do not admit the Buildroot 2025.02.1-pinned 1.8.0.2 archive: the upstream HTTPS endpoint presents a self-signed certificate to the reviewed trust chain, and [NVD CVE-2026-56123](https://nvd.nist.gov/vuln/detail/CVE-2026-56123) lists versions below 1.8.1.2 as affected. Require a verifiable upstream HTTPS artifact, a reviewed newer Buildroot source input, and a standalone no-OpenSSL/no-readline closure before reconsidering it. |
| Native build frontend | target CMake/Ninja | CMake brings a broad `libarchive`/`libuv`/JSON/rhash closure. Admit every new provider before the command; Buildroot's Ninja package is host-only, so a target-Ninja recipe needs a separately locked bootstrap design. |
| Fast LZ4 (source-built and merged; device pending) | `lz4` | The official [LZ4 v1.10.0 tag archive](https://github.com/lz4/lz4/releases/tag/v1.10.0) is the current upstream release and its streamed SHA-256 is `537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b`, identical to Buildroot 2025.02.1. GitHub Actions source batch [`34002789451`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34002789451) restored (not rebuilt) the SDK, built both Buildroot LZ4 directories with `BUILD_SHARED=no`, produced `lz4_1.10.0-1_riscv64.ipk`, and passed locked source, RISC-V ELF, closure, deny-overlay, feed-verification, and 445-object target-coverage gates. Its unsigned artifact [`9980027622`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34002789451/artifacts/9980027622) is 90,226,771 bytes with GitHub SHA-256 `492cc56e4c238cba213ed082db6c0eca955155d12b709711104f9c171f67b3ba`; SDK-base and merge jobs were skipped. No-recompile merge [`34003078163`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34003078163) compared all 38 source-artifact manifest/IPK hashes, rebuilt the index, and again passed feed verification, runtime closure, and 445-object target coverage without compiling; SDK-base and package-build jobs were skipped. It uploaded unsigned merged artifact [`9980152139`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34003078163/artifacts/9980152139), 197,142,393 bytes with GitHub SHA-256 `0964bb1eb75080b69951c3c00808a72398d2a75651162708e79c13d1a062bdaa`. The package extracts only private `lz4`, `lz4c`, `unlz4`, and `lz4cat` command paths with distinct `tdvp-` frontends, never `liblz4.so`, `liblz4.a`, headers, pkg-config metadata, or an ordinary firmware command path. CI did not invoke the codec, give it content, compress data, or extract data. LZ4 framing and checksums are not content authentication. The artifacts are unsigned and still require device lifecycle validation. |
| Parallel LZO (source-built; merge pending) | `lzop` | The official HTTPS LZO 2.10 and lzop 1.04 archives stream to SHA-256 `c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072` and `7e72b62a8a60aff5200a047eea0773a8fb205caf7acbe1774d95147f305a2f41`, respectively, exactly matching Buildroot 2025.02.1. GitHub Actions source batch [`34004037276`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34004037276) restored (not rebuilt) the SDK and actually configured LZO with `-DENABLE_SHARED=OFF -DENABLE_STATIC=ON`; the log records a `liblzo2.a` link, not a shared object. It cross-built `lzop_1.04-1_riscv64.ipk` and passed locked-source, RISC-V ELF, deny-overlay, feed-verification, runtime-closure, and 445-object target-coverage gates; SDK-base and merge jobs were skipped. Its unsigned artifact [`9980420311`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34004037276/artifacts/9980420311) is 90,140,564 bytes with GitHub SHA-256 `698a96674a57f637128102e0c8d15264de49f727e9862f919f36a5cc7ee53cad`. The generic helper extracts only private `lzop` below `/usr/libexec/tdvp-lzop` with `tdvp-lzop` frontend, never `liblzo2.so`, `liblzo2.a`, headers, pkg-config metadata, or an ordinary firmware path. Any surviving `liblzo2` runtime dependency must fail closed. CI did not invoke the codec, give it content, compress data, or extract data. LZO/LZOP framing and checksums are not content authentication. The artifact is unsigned and still requires no-recompile merge plus device lifecycle validation. |
| Parallel gzip (source-built and merged; device pending) | `pigz` | The official [pigz 2.8 source release](https://zlib.net/pigz/) is the current upstream release and its SHA-256 is `eb872b4f0e1f0ebe59c9f7bd8c506c4204893ba6a8492de31df416f0d5170fd0`, identical to the Buildroot 2025.02.1 lock. The original zlib.net transfer endpoint returned 12,031 bytes with hash `8873b211638620c1cbb32ed01a1d6e03ea928a8842566216d2d8040248b97a0c` in run [`34001374220`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34001374220), so source-cache rejected it before compilation with exit 69. The recipe uses the OmniOS public HTTPS mirror only because its 121,304-byte archive exactly matches the upstream/Buildroot hash. This is a transport substitution, not a source replacement or hash relaxation. GitHub Actions source batch [`34001592645`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34001592645) restored (not rebuilt) the SDK, cross-compiled `pigz` with `riscv64-unknown-linux-gnu-gcc`, produced `pigz_2.8-1_riscv64.ipk`, and passed locked source, RISC-V ELF, closure, deny-overlay, feed-verification, and 445-object target-coverage gates. Its unsigned artifact [`9979676644`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34001592645/artifacts/9979676644) is 90,155,403 bytes with GitHub SHA-256 `a022179609394e636be83251319b31af957d52fd47366fcf78bc15058c3791c4`. No-recompile merge [`34001947527`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34001947527) compared all 37 source-artifact manifests/IPK hashes, rebuilt the index, and again passed runtime closure plus 445-object target coverage without compiling; its SDK-base and source-build jobs were skipped. It uploaded unsigned merged artifact [`9979808940`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/34001947527/artifacts/9979808940) (197,003,060 bytes; GitHub SHA-256 `ad8f399d2cbdb0ea1101ce7cb4c03ceb0063021018d968e4da8222f4153950e6`). The package makes one private ELF available only as `tdvp-pigz`, never replaces BusyBox `gzip`, and consumes only the exact immutable `libz` provider; no zlib, headers, static archive, or shared-runtime ABI can enter the IPK. CI did not invoke pigz, give it content, compress data, or extract data. Compression and CRC are not content authentication. No artifact is signed, published, deployed, or run on-device; device lifecycle validation remains required. |

## Promotion rule

“Migrated” is not “released.” A batch enters a release candidate only when
every imported-source package locks its source and patches, offline source-cache
rebuild succeeds, every non-platform SONAME has one owner, the IPKs have no
protected-path changes or RPATH/RUNPATH, a complete matching K230 target passes
install/core-function/uninstall/rollback tests, and it is then signed into an
immutable release.
