# Upstream-source admission and reproducible-packaging contract

[中文](UPSTREAM_SOURCES.zh-CN.md) | English (current)

## Purpose and boundary

The TDVP feed treats Debian, Buildroot, and each project's own upstream
release pages/source repositories as an **upstream-source candidate pool**.
They can supply versions, patches, build knowledge, and security-update
signals; they are not binary package feeds that this device may add directly.

Every IPK published here must be rebuilt from maintainer-selected source with
the exact TDVP platform SDK/sysroot and a reviewed recipe. It reaches a signed,
immutable `rN` release only after admission, reproducibility, ABI, and target
validation. The rule applies equally to software introduced from a Debian
source package, a Buildroot package recipe, a Git tag/commit, a release
tarball, or another public upstream.

```text
Debian source / Buildroot recipe / upstream source release
                         |
                         v
              source.lock + reviewed patches
                         |
                         v
       TDVP pinned SDK/sysroot + package build.sh
                         |
                         v
      staged target payload -> IPK -> ABI/runtime checks
                         |
                         v
    target functional test -> offline signature -> immutable rN -> stable
```

This is a **selective-import** policy. It neither mirrors all packages from a
distribution into IPK nor attempts to become a general RISC-V distribution.
A new package must solve a defined TDVP userland need and have acceptable
maintenance cost, licensing, resource use, and security-update ownership.

## Things that are never directly reused

The following are not permitted:

- adding Debian, Debian Ports, OpenWrt, or an arbitrary generic `riscv64`
  binary repository to the Buildroot/opkg device;
- downloading a `.deb`, or using `dpkg-buildpackage`, `alien`, `ar` extraction,
  or a similar method to “convert” an upstream binary into an `.ipk`;
- putting a prebuilt RISC-V binary made for another glibc, dynamic loader, CPU
  extension set, kernel, or desktop stack below `root/`;
- using a rolling branch, unverified download, build-time `apt install`,
  unpinned tool, or prebuilt host tool as a release input;
- changing the platform ABI manifest, kernel, device tree, boot chain, or base
  firmware merely because an application needs a library or command.

The dynamic loader, the glibc ABI seed (including `libc`, `libdl`, `libm`,
`libpthread`, `librt`, `libutil`, and `libresolv`), `libgcc_s`, `libstdc++`, kernel, kernel
modules, device tree, drivers, firmware blobs, boot chain, init/system
manager, `opkg`, trust root, and platform ABI marker are firmware/platform-ABI
responsibilities. A normal feed package must not introduce, replace, or update
them through `opkg upgrade`. A change to one requires a new platform baseline
and compatibility contract, not an ordinary IPK. See the
[shared-runtime contract](SHARED_RUNTIMES.md) for the precise boundary and
ownership rules for other runtime content.

## Candidate inputs

### Debian

Use **source packages** only: the `.dsc`, upstream `orig` tarball, Debian
maintainer tarball/patch series, and their public metadata. A maintainer may
learn from Debian dependencies, patches, and security fixes, but must adapt,
cross-build, and test the result in the TDVP recipe.

Prefer an immutable source such as a specific Debian source archive version.
Where historical reconstruction is required, record the precise snapshot URL.
An APT binary repository and its `.deb` files are research material only; they
are not a feed build input or runtime dependency.

### Buildroot

A Buildroot package's version, hash, patches, `Config.in`/`.mk` build knowledge,
or declared upstream source may be reused. Do not arbitrarily copy files from a
Buildroot target rootfs into a new package. The limited exception is a
`runtime` provider extracted byte-for-byte from a verified target under the
shared-runtime ownership contract; that transfers ownership, not replaces or
upgrades the base image.

That exception is intentionally narrower than ordinary binary reuse. The
recipe must prove the exact matching platform output, producer/toolchain
identity, file SHA-256, ELF ABI and SONAME, mode, link target, and final
byte-identical base-overlay result. Its `SOURCE_LOCK_EXEMPT_REASON` records
that no third-party source or foreign binary is imported. It cannot be reused
for arbitrary target-rootfs files, additional compiler runtimes, or a changed
toolchain.

For a `buildroot-derived` command package, the feed copies **every** verified
artifact declared by `source.lock` from the TDVP source cache into a
build-private download directory. It passes that directory as `BR2_DL_DIR` and
restricts Buildroot to that local primary site. This includes both target
source and any Buildroot host helper triggered by that exact build path (for
example, host `lzip` needed to extract a `.tar.lz`); such a helper is not an
implicit exception for a tool installed on the build machine and must carry
its own URL, filename, and SHA-256 in the same recipe lock. A filename/hash
mismatch with the Buildroot recipe, or any attempted fallback to a network
mirror, must fail the build. The Buildroot transaction changes the SDK output
configuration only temporarily, restoring the original `.config` and any
pre-existing `.config.old` byte-for-byte; cleanup never uses `olddefconfig` to
silently normalise a maintainer's configuration.

### Staging is a build interface, never an upstream binary source

`TDVP_FEED_STAGING_ROOT` is an ephemeral development sysroot for one feed
candidate. A normal reusable library must enter it by compiling the exact
artifact declared in its own `source.lock`, then may expose headers,
pkg-config metadata, linker symlinks, and the resulting target library to its
declared build dependents. Its IPK still contains only the reviewed runtime
payload for its own SONAME family.

A package that genuinely needs Buildroot's host/target machinery—for example a
reviewed ICU-style two-stage build—must use a locked artifact from the private
offline download directory and state that builder exception in `source.lock`.
It may stage the result of that fresh install, but may not take a replacement
copy from the SDK's existing target rootfs. Consumers must reject missing or
mismatched staging markers rather than silently falling back to a firmware
library. The Node.js provider chain is the current executable example of these
two paths; its release ledger records the remaining device gate.

A Go-style upstream that resolves a large module graph must lock that graph as
well. The main source's `go.mod`/original `go.sum`, the reviewed host Go tool,
the resolved `go.sum`, `vendor/modules.txt`, and the deterministic vendor
archive are all reviewable inputs. Network access is limited to a hash-checked
cache-seed transaction; final target compilation runs with an empty module
cache, `GOPROXY=off`, `GOSUMDB=off`, and `-mod=vendor`. The host Go tool is a
build tool only, never a target ABI provider or IPK payload.

Maintain this boundary by explicitly seeding the cache in a controlled network
phase rather than resolving modules inside a formal offline release build:

```sh
bash ./scripts/prepare-go-module-vendor-cache.sh \
  --package-dir packages/gh --cache .tdvp-source-cache
```

The command prepares only locked source and a host-side vendor cache; it emits
neither an IPK nor a target binary. The subsequent release build uses
`--offline-source-cache`, and a missing bundle or hash mismatch must fail.

### Other upstreams

Git tags/commits, official release tarballs, PyPI/crates.io, and comparable
public source origins can be admitted. The choice must rely on a retrievable
immutable revision and a verifiable hash, never only a moving branch name or a
download landing page.

### Cache-only local Git input

A TDVP-owned or otherwise unpublished Git commit is an exceptional *source
candidate*, not a substitute binary source. It may be admitted only when the
exact commit is available in a reviewed local checkout, `git archive` produces
one hash-locked archive in the controlled source cache, and the recipe's
`source.lock` records that exact archive, commit, filename, and SHA-256. The
release build must consume that cache artifact and fail if it is absent; it
must not fetch a different public snapshot, a moving branch, or an arbitrary
working tree. This remains available for a genuinely unpublished future input.
`tdvp-gba` used to be documented as this exception, but its locked
`4c82b09e1bf042d0709c26ed6c4e5098a283a908` commit and exact HTTPS archive are
now publicly retrievable and hash-locked, so r10 treats it as an ordinary
controlled GitHub cache seed instead.

`--offline-source-cache` also disables historical `REUSE_IPK_URL` payload
reuse. In that mode, a selected recipe is rebuilt from its verified source
cache or explicitly rejected by its reviewed non-source exemption; prior feed
artifacts cannot silently become build inputs.

## Source record for each imported package

After this contract takes effect, every new third-party/upstream-source package
and every existing package whose upstream source, version, or patches change
must commit `packages/<name>/source.lock`. A package that changes only
TDVP-owned documentation or pure data and obtains no third-party source must
state why the record does not apply in its PR.

That exceptional package must also set a non-empty
`SOURCE_LOCK_EXEMPT_REASON='…'` in its `package.env`. CI treats the field only
as an explicit declaration that no third-party source is imported; it cannot
exempt a converted `.deb`, a prebuilt binary, an unpinned download, or a recipe
that should have an upstream provenance record. The sole additional use is the
documented matched-target `runtime` transfer above, which must enforce its
byte-identical ownership checks in the recipe and package gate.

`source.lock` is a human-readable key/value record that should later be parsed
by tooling. It records at least:

- source type (for example `debian-source`, `buildroot-derived`, `git`, or
  `release-tarball`), upstream project, and licence;
- immutable version, Git commit, or release-tarball version—not merely a
  branch; `git` and `buildroot-derived` records require a full 40-character
  lowercase commit SHA rather than a movable tag;
- full URL, filename, and SHA-256 for every downloaded artifact; a Debian
  source package records its `.dsc`, `orig`, Debian tarball, and patch series
  separately;
- the selected snapshot time or repository revision and the reason for the
  choice;
- filename, ordering, SHA-256, and rationale for feed-owned patches;
- filename, SHA-256, and rationale for every non-executable local build input,
  such as a Go module lock;
- non-platform build inputs needed to reproduce the build, plus known
  security-advisory/CVE handling state; and
- a maintainer verification date or PR reference, rather than treating a
  mutable web page as the only evidence.

Start from the [`source.lock.example` template](../packages/_template/source.lock.example).
The record defines the **source supply chain**; `package.env` continues to
define the target IPK's name, version, supported platform, and runtime
relationships. Neither replaces the other.

For the migrated historical scope, the narrow pure-TDVP profile exemptions, and
the next source groups to migrate, see the [source-lock migration
ledger](SOURCE_LOCK_MIGRATION.md). It is an audit checklist; a historical `rN`
label that has not completed admission is not rewritten as candidate evidence.

Published `rN` releases remain immutable and are not retroactively rewritten.
A legacy recipe supplies the record on its next upstream update, significant
refactor, or new release; maintainers may also make a dedicated provenance-only
audit PR.

## Admission decision

Make the decision in this order, never by asking whether upstream happens to
ship a RISC-V package:

1. **Functional ownership:** is it an optional userland application, tool,
   shared runtime, or data item—or a platform/BSP component? Reject or move
   the latter to the firmware project.
2. **Reviewable origin:** can source, patches, licences, and immutable hashes
   be obtained? Reject candidates that cannot be rebuilt or redistributed.
3. **Platform buildability:** can it build only with the selected platform's
   pinned SDK/sysroot? Reject it or create a new platform baseline if it needs
   an ABI-seed replacement, private host tool, or another target libc.
4. **Ownable runtime:** does every non-ABI dynamic SONAME, plugin, exec'd tool,
   and runtime data item have one precise IPK provider/`Depends` relationship?
   It may not silently depend on a base-rootfs copy.
5. **Resources and maintenance:** are storage, memory, startup time, network,
   and privilege needs acceptable on K230, and does someone own version and
   security updates?
6. **Validation:** can it pass source/hash, cross-build, payload/ELF/SONAME
   closure, install/removal, and target functional tests? A successful IPK
   alone does not admit a package.

`shared-library` and `runtime` providers must additionally pass the
byte-identical, unique-SONAME-owner, and ABI-closure checks in the
[shared-runtime contract](SHARED_RUNTIMES.md). Start with a low-risk leaf
application where practical. A new general library must demonstrate reuse and
maintenance value; it must not exist solely to evade the ban on static bundles.

## Build and dependency rules

### Incremental feed construction and CI

The feed is deliberately **not** rebuilt from every source recipe whenever a
single library is admitted.  CI separates three immutable inputs:

1. The **SDK/ABI base** is keyed by the reviewed K230 firmware revision,
   profile and platform-cache version.  It is rebuilt only when that platform
   identity changes; package-source changes do not invalidate it.
2. The **target-runtime IPK base** converts the completed target runtime into
   ordinary feed IPKs once per SDK/ABI base.  It keeps private ownership maps
   with the cache, not beside a public `Packages` index.
3. A **package batch** restores both bases and builds only explicitly selected
   recipes plus their declared source build/runtime dependency closure.  Its
   source cache is addressed by the SHA-256-locked `source.lock` records.

An incremental batch is an unsigned partial candidate.  A later merge gate
may assemble compatible batches only when their platform identity, source
locks, recipe/patch revisions, dependency metadata and IPK SHA-256 values are
recorded and compatible.  It checks the SHA-256 of every declared archive and
rejects non-identical duplicate archive names, with one deliberately narrow
catalogue rule: each batch includes an immutable, private target-runtime base;
when and only when a duplicate filename is an exact IPK-file member of that
restored base, the merge retains its first already manifest-verified copy.  The
base must contain its provenance manifest and must not contain a public
`Packages` index.  This file-membership check covers both top-level SONAME
providers and the generated data/module catalogue, while the manifest itself
supplies no payload.  It cannot exempt source-built packages—those must remain
byte-for-byte identical.  The merge then regenerates the final index and runs both
dependency-closure directions against the restored SDK target.  It must never
substitute an IPK or silently trigger a full rebuild.  A cache miss is a hard
error for a package batch: CI must run the explicit base job, not hide a
platform rebuild inside a library job.

`build.sh` builds only against the selected platform's pinned
`TDVP_SDK_ROOT`, `TDVP_FEED_BASE_ROOT`, and temporary
`TDVP_FEED_STAGING_ROOT`. Build dependencies arrive through
`PACKAGE_BUILD_DEPENDS`; on-device relationships are expressed through exact
`PACKAGE_DEPENDS` versions and the ELF-derived closure in the IPK. The presence
of something on a build host never makes it available on the device.

Do not run upstream Debian packaging rules or a Buildroot `.mk` file directly
as this repository's build script. Their required logic can be ported into a
reviewed `build.sh`, but each TDVP patch, feature selection, and dependency
reduction must be reviewable and reflected in `source.lock` and the package
README. Network retrieval belongs in a hashable, cacheable controlled-fetch
stage; the release build itself should rerun from a verified source cache.

Use the following local workflow. Invoke every script through `bash` so the
working tree's executable bit is not an assumption:

```sh
# Review every committed provenance record.
bash ./scripts/verify-source-lock.sh --repo-root . --all

# Fetch and verify one recipe's source into a SHA-256-addressed cache.
bash ./scripts/fetch-source-cache.sh \
  --cache /srv/tdvp-source-cache \
  --package-dir packages/<package>

# Only when an old build host lacks a trusted root for the upstream HTTPS site,
# use an explicitly managed host-side PEM bundle. This never disables TLS.
bash ./scripts/fetch-source-cache.sh \
  --cache /srv/tdvp-source-cache \
  --package-dir packages/<package> \
  --ca-bundle /etc/ssl/tdvp-controlled-roots.pem

# Once the controlled cache is ready, prohibit network access during the
# release build.
TDVP_SDK_ROOT=/path/to/output/host \
TDVP_FEED_BASE_ROOT=/path/to/output/target \
bash ./scripts/build-all.sh --platform tdvp-k230-r1 --release rN \
  --source-cache /srv/tdvp-source-cache --offline-source-cache --output dist
```

Without an explicit `--source-cache`, `build-all.sh` uses the Git-ignored
`.tdvp-source-cache/` below the repository. It is build cache, not a release
artifact and never a replacement for the locked source record.

`--ca-bundle` is a narrow, host-side trust repair for an obsolete build host or
an enterprise trust chain; it is not an upstream-origin switch. It accepts only
a regular, non-symlink PEM-certificate file and passes it to curl as
`--cacert`; certificate-chain and hostname verification remain enabled, and
the script intentionally has no `--insecure` path. Prefer updating the host
system CA store. Where an exception is necessary, the controlled host
configuration must provide a complete reviewed bundle (`--cacert` replaces
curl's default bundle). In all cases an entry enters the cache only when its
SHA-256 exactly matches `source.lock`. A missing old CA root never authorizes a
switch to a content-different Git tag snapshot, HTTP mirror, or unlocked
download.

## Release gates and evidence

A candidate needs the following evidence for first publication and for every
upstream update:

| Gate | Required evidence |
| --- | --- |
| Source | Complete `source.lock`, matching hashes, licence/redistribution check, reviewed patches |
| Build | Matching platform SDK/sysroot, repeatable recipe, no unpinned retrieval or host-target contamination |
| Package | Correct architecture, exact `tdvp-platform-abi` dependency, no protected-path overlay |
| Runtime | Unique SONAME provider, exact dynamic/explicit-command dependencies, no RPATH/RUNPATH or private general-runtime copy |
| Device | Install, launch/core function, removal, and failure/rollback test; performance and memory records where relevant |
| Release | Feed verification, offline signature, new immutable `rN` snapshot before promotion to `stable` |

The repository parses a committed `source.lock` without executing it, checks
immutable revision/URL/hash/patch fields, places each source artifact in a
content-addressed HTTPS source cache, and verifies its SHA-256 again. CI
requires a `source.lock` or an explicit exemption reason for added or changed
package recipes; `build-all.sh --offline-source-cache` proves that a build no
longer needs the network. Platform ABI, package metadata, runtime
ownership/closure, index, and signature checks remain automated as well. Build
attestations and SBOM/provenance output are still follow-up work; licence,
patch-rationale, and security-advisory judgement remain maintainer review gates
and must not be skipped because automation exists.

## Update and security maintenance

A Debian, Buildroot, or upstream release/security advisory creates a
**candidate update**, not an automatic device update. The maintainer compares
impact, updates `source.lock`, reapplies/reviews patches, rebuilds against the
same TDVP platform, and completes every gate. On success, publish a new `rN`;
do not rewrite an old snapshot, and change `stable` only through the established
promotion process.

When a candidate fix requires a new libc, dynamic loader, kernel/driver,
desktop ABI, or another platform ABI seed, stop the feed update and move it to
base-firmware/new-platform-baseline work. Do not disguise it as an IPK
dependency.

## Phased implementation

This document fixes the governance rule first. Implement automation in order:

1. Completed: introduce and review `source.lock` for new recipes, starting
   with one low-risk pure-Vimscript package;
2. Completed: add controlled HTTPS retrieval, an offline source cache, and
   SHA-256 verification;
3. Completed: parse `source.lock` in build tooling and CI, rejecting
   incomplete, moving, or hash-mismatched sources;
4. Completed: migrate the existing Buildroot-derived `make`, `diffutils`,
   `pkgconf`, `strace`, and `patch` command packages to the locked source
   cache; verify `diffutils`, `patch`, `htop`, `nano`, and the split
   `vim-runtime`/`vim`, self-contained `ca-certificates`, `libexpat-1`, and
   the split `libcrypto-3`/`libssl-3`, `libcurl-4` with its locked source
   closure, the source-admitted same-transaction `curl` recipe, and the
   source-admitted OpenSSL/zlib-only `wget` recipe, the plaintext-only,
   source-admitted `iperf3` recipe, the source-admitted `lsof` recipe, the source-admitted `netcat` recipe, the source-admitted `libevent`/`tmux` split, and the source-admitted
   `libpopt`/`rsync`/OpenSSH split, the
   matched-target `libatomic-1` ownership transfer required by
   curl, the client-only `openssh-client` source cross-build, and the
   explicit client-only `git-runtime`/`git` source split through a verified
   offline source cache,
   and build reviewed `tree`, `which`, the text-tool chain, `htop`, `nano`,
   `vim-runtime`/`vim`, `ca-certificates`, `libexpat-1`,
   `libcrypto-3`/`libssl-3`, `libcurl-4`, `libatomic-1`, `openssh-client`,
   `git-runtime`/`git`, and `archive-tools` with its
   `libbz2`/`liblzma`/`libzstd` runtime closure from locked sources into r10
   candidate RISC-V IPKs;
5. Completed: build the incremental source batches for the same-transaction
   `curl` leaf, OpenSSL/zlib-only `wget`, plaintext-only `iperf3`, `lsof`,
   `netcat`, `libevent`/`tmux`, and `libpopt`/`rsync`, then hash-merge their
   unsigned candidates without recompiling historical source packages;
6. Completed: source batch
   [`33988534267`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988534267)
   has admitted the separately locked, namespaced `gdbserver` and `ethtool`
   debug/network leaves, and no-recompile merge
   [`33988940718`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33988940718)
   admitted their verified artifact without recompiling source packages. Their
   recipes did not change SDK host state, a firmware command path, or a network
   interface; then
7. Completed: source batch
   [`33989899026`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33989899026)
   has admitted the locked static-only `i2c-tools` hardware-inspection leaf;
   no-recompile merge
   [`33990178543`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33990178543)
   admitted its verified artifact without recompiling. It disabled
   Python/py-smbus and shared `libi2c`, and CI did not inspect or change a
   hardware bus; then
8. Completed: GitHub Actions source batch
   [`33991128904`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991128904)
   has admitted the locked no-shared-library `inotify-tools` leaf, and
   no-recompile merge [`33991417095`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991417095)
   then admitted its verified artifact without recompiling. It disabled shared
   `libinotifytools`, exposed only private `inotifywait`/`inotifywatch`
   command ELF files, and never started a watcher or observed a filesystem
   path in CI; then
9. Completed: GitHub Actions source batch
   [`33991963284`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33991963284)
   has admitted the locked command-only `logrotate` leaf, and no-recompile
   merge [`33992249214`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992249214)
   then admitted its verified artifact without recompiling. It disabled
   SELinux/ACL, reused only the immutable target `libpopt` provider, excluded
   `/etc` configuration, timer and daemon payloads, and never ran a log
   rotation operation in CI; then
10. Source batch completed: GitHub Actions source batch
    [`33992855036`](https://github.com/vicliu624/embedded-opkg-feed/actions/runs/33992855036)
    has admitted the locked standalone `jo` command pending a no-recompile
    merge. It remains private, introduces no shared provider, and was never
    invoked or given JSON input in CI; then
11. In progress: admit the locked GNU `ed` line-editor command through a
    GitHub Actions source batch, then a no-recompile merge. host-lzip may only
    unpack the runner source; CI must never invoke the editor or supply a file;
    then
12. Emit source provenance/SBOM material for each release and bind source, SDK,
   and test evidence to the signed release; then
13. Introduce reviewed general libraries incrementally, retaining shared-runtime
   and on-device test gates each time.

Until all automation is complete, this contract remains the admission standard
for every new upstream import. The PR template, contribution guide, and
release checklist cite it so that “candidate source” is never mistaken for “a
distribution package that can be installed directly.”
