# 共享运行时包约定

[中文（当前）](SHARED_RUNTIMES.zh-CN.md) | [English](SHARED_RUNTIMES.md)

TDVP K230 软件源有两种经审核的包类型：

```text
application       命令行工具、桌面程序、设备应用、数据和文档
shared-library    被多个应用复用的运行时 SONAME 库
```

这不是通用 RISC-V 仓库。每个包均为 `riscv64`，属于一个不可变 TDVP feed revision，并由平台清单自动获得精确的 `tdvp-platform-abi` 依赖。

## 所有权边界

Buildroot 镜像拥有启动和运行桌面所需的组件：动态加载器、glibc、libgcc/libstdc++、内核和驱动栈、GTK/Wayland、NetworkManager、PulseAudio/ALSA 以及它们的基础依赖。它们不得由 opkg 重复安装或升级。

feed 是用户态软件和可复用运行时的发行版目录，例如 `sdl2`、`sdl2-ttf` 和 `libmgba`。它应当像正常 Linux 发行版的软件目录一样逐步扩展：共享库、命令行工具、桌面程序和硬件专属应用都以独立包提供。一份库在同一 ABI/feed release 中只编译一次，任意多个包可通过依赖复用它。固件也会在 opkg 已安装数据库中登记自己的 seed/base package，使依赖图不会把已经存在的桌面运行时当作不可追踪的黑箱。

## Recipe 元数据

每个 recipe 同时声明构建顺序和安装后的运行时依赖：

```sh
PACKAGE_KIND='shared-library'        # 或 application
PACKAGE_RELEASES='r2'
PACKAGE_SECTION='libraries'          # 例如 libraries、utils、desktop、games
PACKAGE_BUILD_DEPENDS='sdl2'         # 仅构建 staging
PACKAGE_DEPENDS='sdl2 (= 2.30.11-1)' # opkg 运行时关系
```

`build-all.sh` 为一次 release 创建一个临时 `TDVP_FEED_STAGING_ROOT`。库 recipe 的头文件、CMake 元数据和未版本化 linker symlink 只进入此 staging；最终 `.ipk` 只能包含运行时 `lib*.so*` 和属于该包的许可/文档。应用从同一 staging 动态链接，不能再复制这些库到自身载荷。

## 强制发布检查

不可变 feed 签名前，发布构建会验证：

- feed 文件不会替换匹配 target root 中已有文件；
- 共享库不得写入受保护的 loader/glibc/libstdc++ 文件；
- 两个 feed 包不能导出同一 ELF SONAME；
- 所有载荷 ELF 均不得携带 RPATH/RUNPATH；
- 每个直接 `NEEDED` SONAME 必须来自基础 rootfs 或一个已声明的 feed 依赖。

构建含共享库的 feed 时必须提供 `TDVP_FEED_BASE_ROOT=<匹配的 Buildroot target>`。只看 recipe 元数据不足以签发一个库 release。

`tdvp-` 只保留给 TDVP 平台拥有的包（例如 `tdvp-gba`），并不是通用第三方库的前缀。通用库保留上游名称；由 feed 的平台 ABI 依赖与 `Architecture: riscv64` 限定其安全安装范围。
