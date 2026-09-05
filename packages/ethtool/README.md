# ethtool Ethernet-diagnostic candidate

`ethtool` builds the Buildroot 2025.02.1-selected 6.14 kernel.org archive from
the source lock. Its private transaction disables the optional netlink/libmnl
and pretty-dump branches, so it introduces no new shared runtime provider.

The candidate owns only `/usr/libexec/tdvp-ethtool/ethtool` and the explicit
`/usr/bin/tdvp-ethtool` wrapper. It does not replace a firmware command, copy
from the target root, or import a Debian binary.

CI only builds and audits this tool. It never changes Ethernet speed, duplex,
offloads, queues, driver state, or firmware. Any device validation must use an
explicit non-production interface and record install/uninstall/rollback.
