# Published SDK builds

The r10 feed consumes the CPU0 application SDK from firmware Release
`v2026.09.12-r10`. The SDK archive, its manifest and the paired compressed
image are content-addressed build inputs. A firmware checkout, completed
Buildroot output, download stamps and GitHub Actions SDK caches are not
evidence of the published image's identity.

The SDK supplies target compilers, development files and CPU0 scalar defaults.
Native build generators belong to the build host. Feed-only development
artifacts belong to the release's disposable staging directory. Neither a
recipe nor its build system may write into the published SDK.

Runtime package contents and ownership come from the paired final image and
its verified inventory, not from development sysroot contents. SDK headers and
unversioned linker files must never become image-runtime packages. Existing
ELF, dependency, ownership and immutable-image audits remain required.

Application recipes build their locked upstream sources with the SDK. They
must not require firmware `.config`, package installation stamps or a mutable
firmware `target/`. Existing immutable feed releases remain unchanged.

The active candidate workflow now accepts r10. Historical recipe paths remain
available for historical Buildroot inputs, but neither active workflow invokes
them. Source-bearing historical IPKs are not reused in published-SDK builds:
the CPU0 scalar policy must be checked on newly built artifacts. Read-only,
byte-identical runtime transfers from the paired final image remain permitted.

The incremental workflow retains the `build-sdk-base` input spelling for
callers; it now prepares and packages the released image's runtime catalogue.
It does not compile an SDK. The runtime cache identity includes the SDK archive
digest, and old Buildroot cache entries cannot satisfy it.

Audacious is built directly with Meson using the reviewed feature list.
Other source builders use the locked upstream build systems. CPython's native
interpreter and ICU's native generators are built from their matching locked
sources in private staging. Node consumes those native ICU tools separately
from its RISC-V dependencies. The released SDK is verified before use, and all
new package ELFs are checked by its CPU0 verifier before IPK assembly.
