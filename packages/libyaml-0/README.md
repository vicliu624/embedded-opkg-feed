# libyaml-0 shared runtime provider

`libyaml-0` builds LibYAML 0.2.5 only from the source archive recorded in
`source.lock`, using Buildroot 2025.02.1 in a private GitHub Actions
transaction. It owns the public `libyaml-0.so.2` ABI and its required relative
runtime symlinks below `/usr/lib`; it owns no headers, static archives,
pkg-config metadata, target-root copy, Debian binary, or application command.

This is an independently versioned provider, not an application-bundled
library. Any future YAML application must declare an exact dependency on this
package after its own source-built K230 closure has passed. Candidate CI verifies
the locked archive, RISC-V ELF identity, RPATH/RUNPATH, runtime closure, and
base-overlay ownership before uploading an unsigned artifact.
