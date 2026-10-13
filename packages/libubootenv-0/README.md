# Historical runtime migration

The four migrated providers (`libyaml-0-2`, `libmxml-1`, `libmicrohttpd-12`,
`libubootenv-0`) retain the historical distribution version sequence:
`2025.02.1-1` becomes `2025.02.1-2`. Upstream versions and archive identities
are recorded independently in each `source.lock`. This avoids presenting an
upstream version such as `0.3.5-1` as a downgrade from the old package version.

All four libraries are rebuilt with the CPU0 SDK. Historical r6 payloads declare
RVV 1.0 extensions and fail current CPU0 ISA validation; they must not be reused.

libubootenv consumes `libyaml-0-2` development staging and the platform zlib
development provider. It exports `libubootenv.so.0` as an independent runtime
package. The library build does not execute environment-management utilities,
write bootloader environment storage or alter boot configuration.

Its generated private CMake toolchain includes the SDK toolchain, then selects
the disposable dependency sysroot and target pkg-config environment. The SDK
and platform image remain read-only build inputs.
