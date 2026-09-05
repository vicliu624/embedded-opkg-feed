# exfatprogs narrow filesystem-tools cohort

`exfatprogs` builds exfatprogs 1.2.5 only from the archive recorded in
`source.lock`, using Buildroot 2025.02.1 in a private GitHub Actions
transaction. It owns source-built RISC-V ELF files only below
`/usr/libexec/tdvp-exfatprogs/`; its public commands are the explicit,
collision-free `/usr/bin/tdvp-exfat-*` wrappers. It never owns an unprefixed
command, `/bin/*`, `/sbin/*`, a firmware file, a copied target-root library,
or a Debian binary.

The reviewed command set is deliberately finite: `mkfs.exfat`, `fsck.exfat`,
`dump.exfat`, `exfat2img`, `tune.exfat`, and `exfatlabel`. The suite has no
Buildroot runtime package dependencies. The package still proves its actual
RISC-V runtime closure during the candidate CI; a newly discovered shared
library or base-overlay path fails the batch instead of becoming an implicit
firmware dependency.

Several selected programs create, repair, tune, or label filesystems, and
`exfat2img` writes an image. CI only retrieves locked source, cross-compiles,
packages, and audits ABI/path closure; it never executes these programs. Any
device validation must use non-production media, an explicitly selected target,
recorded install/uninstall/rollback, and only then can a signed release be
considered.
