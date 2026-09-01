# TDVP K230 r1 platform contract

[中文](PLATFORM.zh-CN.md) | English (current)

## Confirmed target facts

These values were read from the target device rather than inferred from the
board name. The machine-readable manifest is
[`platforms/tdvp-k230-r1/platform.env`](../platforms/tdvp-k230-r1/platform.env).

| Field | Value |
| --- | --- |
| Board identity | TDVP K230 / `tdisplay-k230` |
| CPU architecture | RISC-V 64-bit |
| Loader ABI | `riscv64-lp64d` |
| Dynamic loader | `/lib/ld-linux-riscv64-lp64d.so.1` |
| C library | GNU libc 2.33 |
| Kernel | 6.6.36 |
| Base OS | vendor-customised Buildroot 2025.02.1 |
| Package manager | opkg 0.7.0 |

## Release rule

The `PLATFORM_ID` identifies a complete binary compatibility contract, not
just a CPU architecture. A platform maintainer must create a new platform
manifest and feed path whenever any of these change:

- Buildroot/vendor source revision or defconfig;
- toolchain, sysroot, glibc, C++ ABI, or hard-float ABI;
- kernel release for packages that interact with the kernel;
- KPU/GPU/AI2D runtime ABI;
- a compositor/protocol ABI change in the core Wayland stack.

The last item means a change to the compositor or protocol ABI that every
Wayland client must share. It does **not** mean a library, desktop feature, or
helper executable needed by one application. Add those as ordinary feed
packages with exact dependencies; do not create a new platform ABI for them.

Packages use the following dependency gate:

```text
Depends: tdvp-platform-abi (= 2025.02.1-k230.6.6.36-glibc2.33-rv64-lp64d-r1)
```

The base firmware must register that marker as installed. A package that
cannot satisfy this dependency must not be installed with `--force-depends`.

## Explicit exclusions

Application packages must not replace files in `/boot`, `/lib`, `/lib64`,
`/usr/lib`, `/usr/lib/systemd`, `/usr/sbin`, or `/etc` unless a reviewed
firmware-level exception is approved. Do not publish kernel modules in this
feed: their compatibility requires an exact kernel build identity, not merely
the kernel version string.
