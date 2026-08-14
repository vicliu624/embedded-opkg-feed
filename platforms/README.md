# Supported platforms

Each directory under `platforms/` is a separately reviewed binary
compatibility contract. A platform is not merely a CPU architecture: it fixes
the firmware line, toolchain/sysroot, dynamic-loader ABI, base libraries, and
the package feed location.

Packages declare the platform slugs they support. The packager injects that
platform's ABI-marker dependency into every generated `.ipk`.

Adding a platform is a maintainer-only change. It requires a new base firmware
with a registered ABI marker and a tested signature-verification path before a
public feed may be published.
