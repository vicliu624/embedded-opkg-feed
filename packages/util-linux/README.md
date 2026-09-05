# util-linux narrow command cohort

util-linux-tools builds util-linux 2.40.2 only from the archive locked in
source.lock, using Buildroot 2025.02.1 in a private GitHub Actions
transaction. It owns source-built RISC-V ELF files only below
/usr/libexec/tdvp-util-linux/; its public programs are explicit
/usr/bin/tdvp-util-linux-* wrappers. It never owns an unprefixed command,
/bin/*, /sbin/*, a firmware file, a copied target-root library, or a Debian
binary.

The selected command set is intentionally narrow: cal, fallocate, IPC
inspection/control, process/session helpers, scheduling helpers, namespace
helpers, terminal messaging, and account-record inspection. It does not
select util-linux basic binaries, mount/umount, filesystem/partition/loop
device utilities, wipefs, login/su/runuser, setpriv, or the
libblkid/libfdisk/libmount/libsmartcols/libuuid feature families. Those
capabilities require a separately versioned shared-library/provider review.

Several selected commands can change process, IPC, namespace, filesystem, or
terminal state when a device user invokes them. CI only obtains locked source,
cross-compiles, packages, and audits ABI/path closure; it never executes these
commands. Any device validation must use a non-production test unit, explicit
targets, recorded install/uninstall/rollback, and only then can a signed
release be considered.
